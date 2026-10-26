import json

packs = [
    'assets/rules/v1/munchkin_core.json',
    'assets/rules/v1/munchkin_expansions.json',
    'assets/rules/v1/munchkin_spinoffs.json',
    'assets/rules/v1/munchkin_2_0.json'
]

for p in packs:
    with open(p, 'r', encoding='utf-8') as f:
        data = json.load(f)
    for b in data.get('ruleBlocks', []):
        r = b.get('relatedEntityIds', [])
        if r:
            print(f"{p}: block '{b['id']}' ({b.get('title')}) -> {r}")
