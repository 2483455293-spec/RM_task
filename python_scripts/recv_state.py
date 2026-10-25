import socket
import json

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", 9001))
    server.listen(1)
    print("[INFO] 监听 状态通道 9001，等待 Godot 连接...")

    while True:
        conn = None
        try:
            conn, addr = server.accept()
            print(f"[INFO] 状态客户端已连接: {addr}")
            
            buffer = ""
            while True:
                data = conn.recv(4096)
                if not data:
                    break
                buffer += data.decode('utf-8')
                # 按换行符切分 JSON
                while '\n' in buffer:
                    line, buffer = buffer.split('\n', 1)
                    if line.strip():
                        try:
                            state = json.loads(line)
                            print(f"[状态更新] 时间: {state.get('time_left'):.1f}s | HP: {state.get('hp')} | 弹量: {state.get('ammo')} | 热量: {state.get('heat')}")
                        except json.JSONDecodeError:
                            pass
        except ConnectionError:
            print("[WARN] 状态连接断开，等待重连...")
        finally:
            if conn: conn.close()

if __name__ == "__main__":
    main()