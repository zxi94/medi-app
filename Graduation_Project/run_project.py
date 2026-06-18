import subprocess
import sys
import os
import time
import threading

def stream_output(process, name):
    for line in iter(process.stdout.readline, ''):
        print(f"[{name}] {line.strip()}")

def run():
    print("🚀 Starting Graduation Project Services...")
    
    # 1. Start the Mock AI Server
    ai_dir = os.path.abspath("ai_microservice")
    ai_script = os.path.join(ai_dir, "mock_ai_server.py")
    if not os.path.exists(ai_script):
        print(f"❌ Could not find Mock AI script at: {ai_script}")
        return

    print("🤖 Starting Mock AI Server on port 8000...")
    ai_process = subprocess.Popen(
        [sys.executable, ai_script],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )
    
    # Wait a moment for the AI server to bind to port 8000
    time.sleep(2)
    
    # 2. Start the Backend Server
    backend_dir = os.path.abspath("backend")
    if not os.path.exists(backend_dir):
        print(f"❌ Could not find backend directory at: {backend_dir}")
        ai_process.terminate()
        return

    print("🖥️ Starting Backend Server on port 5001...")
    backend_process = subprocess.Popen(
        "npm run dev",
        cwd=backend_dir,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )

    # Start stdout/stderr streaming threads
    threading.Thread(target=stream_output, args=(ai_process, "AI Server"), daemon=True).start()
    threading.Thread(target=stream_output, args=(backend_process, "Backend"), daemon=True).start()

    print("\n✅ Both servers are running!")
    print("👉 Mock AI Server: http://localhost:8000")
    print("👉 Backend Server: http://localhost:5001")
    print("Press Ctrl+C to gracefully stop both servers.\n")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nStopping services...")
        ai_process.terminate()
        backend_process.terminate()
        print("Goodbye!")

if __name__ == '__main__':
    run()
