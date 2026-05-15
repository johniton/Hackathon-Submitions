import os
import glob
import re

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace FloatingActionButton(
    new_content = re.sub(r'FloatingActionButton\(', 'FloatingActionButton(heroTag: null, ', content)
    # Replace FloatingActionButton.extended(
    new_content = re.sub(r'FloatingActionButton\.extended\(', 'FloatingActionButton.extended(heroTag: null, ', new_content)
    
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed {filepath}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))

print("Done")
