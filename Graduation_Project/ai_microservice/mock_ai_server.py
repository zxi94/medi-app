import http.server
import json

class MockAIHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Silence standard HTTP logging to keep console clean
        pass

    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "models_loaded": True}).encode())
        elif self.path == '/findings':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "findings": [
                    {"name_en": "Pneumonia", "name_ar": "التهاب رئوي"},
                    {"name_en": "Normal", "name_ar": "طبيعي"}
                ]
            }).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length) if content_length > 0 else b''

        if self.path == '/predict':
            # 1x1 black PNG base64 representation
            mock_heatmap_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
            response = {
                "diagnosis_output": {
                    "label": "Pneumonia",
                    "confidence": 0.85
                },
                "heatmap_path": "uploads/mock_heatmap.png",
                "heatmaps": {
                    "Pneumonia": mock_heatmap_base64
                },
                "bounding_boxes": [],
                "predictions": ["Pneumonia"]
            }
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())

        elif self.path == '/generate_report':
            response = {
                "findings": "There is a consolidation in the right lower lobe consistent with pneumonia.",
                "impression": "Right lower lobe pneumonia.",
                "recommendations": "Clinical correlation and follow-up after treatment.",
                "full_report": "Findings: Consolidation in right lower lobe.\nImpression: Pneumonia.\nRecommendations: Follow up."
            }
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())

        elif self.path == '/chat':
            try:
                data = json.loads(post_data.decode('utf-8'))
                question = data.get("question", "").lower()
                finding = data.get("finding", "General Health")
            except Exception:
                question = ""
                finding = "General Health"

            answer = "I am your AI health assistant. I can help explain your chest X-ray findings. Please consult your doctor for specific medical advice."
            
            if "opacity" in question or "عتامة" in question:
                answer = "Lung opacity refers to an area in the lung that looks white or hazy on a chest X-ray. It indicates that the lung tissue is denser than normal, which can be caused by fluid, infection (like pneumonia), inflammation, or other conditions. Please consult your physician for a detailed clinical evaluation."
            elif "consolidation" in question or "تصلب" in question or "تكثف" in question:
                answer = "Consolidation indicates that the normal air-filled spaces in your lungs are filled with fluid, pus, or inflammatory cells instead of air. It is a common finding in active lung infections like pneumonia."
            elif "cardiomegaly" in question or "تضخم" in question:
                answer = "Cardiomegaly refers to an enlarged heart on chest imaging. It is a sign of an underlying condition (such as high blood pressure or heart failure) rather than a disease itself. Your doctor will correlate this finding with your symptoms."
            elif "effusion" in question or "انصباب" in question:
                answer = "Pleural effusion is a build-up of excess fluid in the space between the lungs and the chest wall. It can cause difficulty breathing or chest pain and requires a physician's evaluation to determine the cause."
            elif "pneumonia" in question or "التهاب رئوي" in question:
                answer = "Pneumonia is an infection that inflames the air sacs in one or both lungs, which may fill with fluid or pus. Common symptoms include cough, fever, chills, and difficulty breathing."
            elif "hello" in question or "hi" in question or "مرحبا" in question or "اهلا" in question:
                answer = f"Hello! I'm your AI health assistant. I am ready to help you understand your chest X-ray diagnosis ({finding}). How can I help you today?"
            elif "thank" in question or "شكرا" in question:
                answer = "You're very welcome! If you have any other questions about your chest X-ray findings, feel free to ask. Stay healthy!"

            response = {
                "answer": answer,
                "finding": finding,
                "success": True
            }
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    server = http.server.HTTPServer(('0.0.0.0', 8000), MockAIHandler)
    print("Mock AI Server running on port 8000...")
    server.serve_forever()
