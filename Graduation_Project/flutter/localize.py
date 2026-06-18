import json
import os
import sys

def localize_file(filepath, replacements_json_path):
    with open(replacements_json_path, 'r', encoding='utf-8') as f:
        replacements = json.load(f)

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Add import if not exists
    if 'package:flutter_gen/gen_l10n/app_localizations.dart' not in content:
        content = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';\n" + content

    for original, key in replacements.items():
        # Replace single quoted
        content = content.replace(f"'{original}'", f"loc.{key}")
        # Replace double quoted
        content = content.replace(f'"{original}"', f"loc.{key}")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Localized {filepath}")

if __name__ == "__main__":
    localize_file(sys.argv[1], sys.argv[2])
