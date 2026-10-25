import socket
import struct
import cv2
import numpy as np
import time

def recv_exact(conn, n):
    data = bytearray()
    while len(data) < n:
        chunk = conn.recv(n - len(data))
        if not chunk:
            raise ConnectionError("disconnected")
        data.extend(chunk)
    return bytes(data)

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", 9000))
    server.listen(1)
    print("[INFO] 监听 图像通道 9000，等待 Godot 连接...")

    while True:
        conn = None
        try:
            conn, addr = server.accept()
            print(f"[INFO] 图像客户端已连接: {addr}")
            
            last_time = time.time()
            fps_count = 0
            
            while True:
                header = recv_exact(conn, 20)
                # 注意：这里变量叫 ts_us，对应 Godot 的 get_ticks_usec
                magic, seq, ts_us, size = struct.unpack(">4sIQI", header)

                if magic != b"RMV1" or not 0 < size <= 2_000_000:
                    print(f"[ERROR] 协议错误 magic={magic}")
                    break
                
                jpeg_data = recv_exact(conn, size)
                buf = np.frombuffer(jpeg_data, dtype=np.uint8)
                frame = cv2.imdecode(buf, cv2.IMREAD_COLOR)

                if frame is None:
                    print(f"[WARN] 帧 {seq} JPEG解码失败，丢弃")
                    continue
                
                # 简单计算接收帧率
                fps_count += 1
                if time.time() - last_time >= 1.0:
                    print(f"[INFO] 图像通道接收FPS: {fps_count} | 最新帧: {seq}, 大小: {size/1024:.1f}KB")
                    fps_count = 0
                    last_time = time.time()

                # 在窗口中显示，并在左上角打上帧号
                cv2.putText(frame, f"Seq: {seq}", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
                cv2.imshow("Image Channel (9000)", frame)
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    return
        except ConnectionError:
            print("[WARN] 图像连接断开，等待重连...")
        finally:
            if conn: conn.close()

if __name__ == "__main__":
    main()