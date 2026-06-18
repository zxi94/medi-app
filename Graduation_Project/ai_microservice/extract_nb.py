import json
import sys
import os

def extract_notebook(path, out_path):
    with open(path, 'r', encoding='utf-8') as f:
        nb = json.load(f)
    
    with open(out_path, 'w', encoding='utf-8') as out:
        for i, cell in enumerate(nb['cells']):
            if cell['cell_type'] == 'code':
                source = ''.join(cell['source'])
                out.write(f"# === CELL {i} ===\n")
                out.write(source)
                out.write("\n\n")

base = r'e:\Downloads\final Chest-X_ray-diagnosis-system-Backend-Ziad (1)\Chest-X_ray-diagnosis-system-Backend-Ziad\ai_microservice'

extract_notebook(os.path.join(base, 'model_setup.ipynb'), os.path.join(base, 'model_setup_code.py'))
extract_notebook(os.path.join(base, 'raddino-deployment-final-final-final-final.ipynb'), os.path.join(base, 'gradio_deploy_code.py'))
extract_notebook(os.path.join(base, 'chest-xray-report-generation.ipynb'), os.path.join(base, 'report_gen_code.py'))
extract_notebook(os.path.join(base, 'chatbot-feelings.ipynb'), os.path.join(base, 'chatbot_code.py'))

print("Done extracting all notebooks")
