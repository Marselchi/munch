import json
import os
import re

TERMS = [
    {
        'id': 'term_big_item',
        'aliases': ['большая шмотка', 'большие шмотки', 'большой шмотки', 'большую шмотку', 'большими шмотками', 'больших шмотках', 'больших шмоток', 'big item', 'big items'],
        'stems': []
    },
    {
        'id': 'term_enhancer',
        'aliases': ['усилитель шмоток', 'усилитель шмотки', 'усилители шмоток', 'усилителем шмотки', 'усилителями шмоток', 'item enhancer', 'item enhancers'],
        'stems': []
    },
    {
        'id': 'term_style_enhancer',
        'aliases': ['усилитель стиля', 'усилители стиля', 'усилителем стиля', 'усилителями стилей'],
        'stems': []
    },
    {
        'id': 'term_bad_stuff',
        'aliases': ['плохая штука', 'плохой штуки', 'плохую штуку', 'плохой штукой', 'плохих штук', 'непотребство', 'непотребства', 'непотребству', 'непотребством', 'непотребств', 'bad stuff'],
        'stems': ['непотребств']
    },
    {
        'id': 'term_combat_strength',
        'aliases': [
            'боевая сила',
            'боевой силы',
            'боевой силе',
            'боевую силу',
            'боевой силой',
            'боевые силы',
            'боевых сил',
            'боевым силам',
            'боевыми силами',
            'суммарной боевой силой',
            'суммарная боевая сила',
            'суммарную боевую силу',
            'бонус боевой силы',
            'бонуса боевой силы',
            'бонусом боевой силы',
            'очков боевой силы',
            'очка боевой силы',
            'очко боевой силы',
            'силу монстра',
            'силы монстра',
            'силе монстра',
            'силой монстра',
            'силы монстров',
            'силам монстров',
            'силами монстров',
            'сил монстров',
            'сила монстра',
            'combat strength'
        ],
        'stems': []
    },
    {
        'id': 'term_combat',
        'aliases': ['бой', 'боя', 'бою', 'боем', 'бое', 'бои', 'боев', 'боям', 'боями', 'боях', 'combat'],
        'stems': []
    },
    {
        'id': 'term_level',
        'aliases': ['уровень', 'уровня', 'уровню', 'уровнем', 'уровне', 'уровни', 'уровней', 'уровням', 'уровнями', 'уровнях', 'level'],
        'stems': ['уровн']
    },
    {
        'id': 'term_class',
        'aliases': ['класс', 'класса', 'классу', 'классом', 'классе', 'классы', 'классов', 'классам', 'классами', 'классах', 'class'],
        'stems': ['класс']
    },
    {
        'id': 'term_race',
        'aliases': ['раса', 'расы', 'расе', 'расу', 'расой', 'расам', 'расами', 'расах', 'race'],
        'stems': []
    },
    {
        'id': 'term_item',
        'aliases': ['шмотка', 'шмотки', 'шмотке', 'шмотку', 'шмоткой', 'шмоток', 'шмоткам', 'шмотками', 'шмотках', 'item', 'items'],
        'stems': ['шмотк']
    },
    {
        'id': 'term_monster',
        'aliases': ['монстр', 'монстра', 'монстру', 'монстром', 'монстре', 'монстры', 'монстров', 'монстрам', 'монстрами', 'монстрах', 'monster'],
        'stems': ['монстр']
    },
    {
        'id': 'term_curse',
        'aliases': ['проклятие', 'проклятия', 'проклятию', 'проклятием', 'проклятии', 'проклятий', 'проклятиям', 'проклятиями', 'curse'],
        'stems': ['проклят']
    },
    {
        'id': 'term_runaway',
        'aliases': ['смывка', 'смывки', 'смывке', 'смывку', 'смывкой', 'смываться', 'смылся', 'смыться', 'run away'],
        'stems': ['смыв']
    },
    {
        'id': 'term_hireling',
        'aliases': ['наёмник', 'наемник', 'наёмника', 'наемника', 'наёмнику', 'наемнику', 'наёмником', 'наемником', 'наёмники', 'наемники', 'наёмников', 'наемников', 'соратник', 'соратника', 'миньон', 'приспешник', 'союзник', 'hireling'],
        'stems': ['наемник', 'наёмник']
    },
    {
        'id': 'term_steed',
        'aliases': ['скакун', 'скакуна', 'скакуну', 'скакуном', 'скакуне', 'скакуны', 'скакунов', 'скакунам', 'скакунами', 'скакунах', 'steed'],
        'stems': ['скакун']
    },
    {
        'id': 'term_dungeon',
        'aliases': ['подземелье', 'подземелья', 'подземелью', 'подземельем', 'подземелий', 'подземельям', 'подземельями', 'подземельях', 'dungeon'],
        'stems': ['подземел']
    },
    {
        'id': 'term_portal',
        'aliases': ['портал', 'портала', 'порталу', 'порталом', 'портале', 'порталы', 'порталов', 'порталам', 'порталами', 'порталах', 'portal'],
        'stems': ['портал']
    },
    {
        'id': 'term_seal',
        'aliases': ['печать', 'печати', 'печатей', 'печатям', 'печатями', 'печатях', 'сивучать', 'сивучати', 'сивучатей', 'сивучатями', 'сивучатях', 'seal', 'seals'],
        'stems': ['печат', 'сивучат']
    },
    {
        'id': 'term_disaster',
        'aliases': ['катастрофа', 'катастрофы', 'катастрофе', 'катастрофу', 'катастрофой', 'катастроф', 'катастрофам', 'катастрофами', 'катастрофах', 'disaster'],
        'stems': ['катастроф']
    },
    {
        'id': 'term_mojo',
        'aliases': ['моджо', 'mojo'],
        'stems': ['моджо']
    },
    {
        'id': 'term_madness',
        'aliases': ['безумие', 'безумия', 'безумию', 'безумием', 'безумий', 'безумиях', 'madness'],
        'stems': ['безуми']
    },
    {
        'id': 'term_accent',
        'aliases': ['акцент', 'акцента', 'акценту', 'акцентом', 'акценте', 'акценты', 'акцентов', 'акцентам', 'акцентами', 'акцентах', 'accent'],
        'stems': ['акцент']
    },
    {
        'id': 'term_ship',
        'aliases': ['корабль', 'корабля', 'кораблю', 'кораблём', 'корабле', 'корабли', 'кораблей', 'кораблям', 'кораблями', 'кораблях', 'ship'],
        'stems': ['корабл']
    },
    {
        'id': 'term_style',
        'aliases': ['стиль', 'стиля', 'стилю', 'стилем', 'стиле', 'стили', 'стилей', 'стилям', 'стилями', 'стилях', 'style'],
        'stems': ['стил']
    },
    {
        'id': 'term_power',
        'aliases': [
            'карта сил', 'карты сил', 'карте сил', 'карту сил', 'картой сил', 'картами сил', 'картах сил',
            'ранг сил', 'ранги сил', 'рангом сил', 'рангов сил', 'ранга сил', 'рангами сил', 'рангах сил',
            'ранг силы', 'ранга силы', 'рангу силы', 'рангом силы', 'ранге силы', 'ранги силы', 'рангов силы',
            'сила с рангом', 'силы с рангами', 'силу с рангом', 'силами с рангами',
            'суперсила', 'суперсилы', 'суперсилу', 'суперсилой', 'суперсил',
            'силы и ранги', 'силы (powers)', 'сила (power)', 'подготовка и силы',
            'power', 'powers'
        ],
        'stems': []
    },
    {
        'id': 'term_ancient',
        'aliases': ['древний', 'древнего', 'древнему', 'древним', 'древнем', 'древние', 'ancient'],
        'stems': ['древн']
    },
    {
        'id': 'term_elite',
        'aliases': ['элитный', 'элитного', 'элитному', 'элитным', 'элитном', 'элитные', 'elite'],
        'stems': ['элитн']
    },
    {
        'id': 'term_legendary',
        'aliases': ['легендарный', 'легендарного', 'легендарному', 'легендарным', 'легендарном', 'легендарные', 'legendary'],
        'stems': ['легендарн']
    },
    {
        'id': 'term_charity',
        'aliases': ['щедрость', 'щедрости', 'щедростью', 'от щедрот', 'милосердие', 'charity'],
        'stems': ['щедрост']
    },
    {
        'id': 'term_treasure',
        'aliases': ['сокровище', 'сокровища', 'сокровищу', 'сокровищем', 'сокровищ', 'сокровищам', 'сокровищами', 'сокровищах', 'treasure'],
        'stems': ['сокровищ']
    },
    {
        'id': 'term_training',
        'aliases': [
            'подготовка (munchkin impossible)', 'подготовка из munchkin impossible',
            'шпионская подготовка', 'шпионской подготовки', 'карту подготовки', 'карты подготовки', 'карта подготовки',
            'стили, подготовка и силы', 'стили и подготовка'
        ],
        'stems': []
    },
    {
        'id': 'term_laser',
        'aliases': ['лазер', 'лазера', 'лазеру', 'лазером', 'лазере', 'лазеры', 'лазеров', 'лазерам', 'лазерами', 'лазерах', 'лазер-мазер-фазер', 'laser'],
        'stems': ['лазер']
    }
]

# Build flat alias lookup sorted by length descending
alias_lookup = []
for item in TERMS:
    term_id = item['id']
    for a in item['aliases']:
        alias_lookup.append((a.lower(), term_id))

# Sort longer phrases first
alias_lookup.sort(key=lambda x: len(x[0]), reverse=True)

# Build stem lookup
stem_lookup = []
for item in TERMS:
    term_id = item['id']
    for s in item.get('stems', []):
        stem_lookup.append((s.lower(), term_id))
stem_lookup.sort(key=lambda x: len(x[0]), reverse=True)

def is_word_char(c):
    if not c:
        return False
    return c.isalnum() or c in '_-'

def parse_text_to_spans(text):
    if not text:
        return []
    
    lower = text.lower()
    matches = []

    # 1. Exact alias matches (longer first)
    for alias, term_id in alias_lookup:
        start_search = 0
        while start_search < len(lower):
            idx = lower.find(alias, start_search)
            if idx == -1:
                break
            end_idx = idx + len(alias)

            # Check word boundary
            left_ok = (idx == 0) or not is_word_char(lower[idx - 1])
            right_ok = (end_idx >= len(lower)) or not is_word_char(lower[end_idx])

            if left_ok and right_ok:
                # Check collision with already matched spans
                collision = any(
                    (idx >= m[0] and idx < m[1]) or (end_idx > m[0] and end_idx <= m[1])
                    for m in matches
                )
                if not collision:
                    matches.append((idx, end_idx, term_id))
            start_search = idx + 1

    # 2. Word-by-word stem matching for any words not already covered
    words = list(re.finditer(r'[a-zA-Zа-яА-ЯёЁ0-9_-]+', text))
    for w in words:
        w_start, w_end = w.start(), w.end()
        w_text = w.group().lower()

        # Check if already covered
        covered = any(w_start >= m[0] and w_end <= m[1] for m in matches)
        if not covered:
            for stem, term_id in stem_lookup:
                if w_text.startswith(stem):
                    matches.append((w_start, w_end, term_id))
                    break

    # Sort spans by start
    matches.sort(key=lambda x: x[0])
    return matches

def main():
    packs = [
        'assets/rules/v1/munchkin_core.json',
        'assets/rules/v1/munchkin_expansions.json',
        'assets/rules/v1/munchkin_spinoffs.json',
        'assets/rules/v1/munchkin_2_0.json'
    ]

    texts = set()
    for p in packs:
        with open(p, 'r', encoding='utf-8') as f:
            data = json.load(f)
        for b in data.get('ruleBlocks', []):
            t = b.get('text', '').strip()
            if t:
                texts.add(t)
        for e in data.get('entities', []):
            for s in e.get('ruleSections', []):
                t = s.get('text', '').strip()
                if t:
                    texts.add(t)
            if e.get('epic'):
                for s in e['epic'].get('ruleSections', []):
                    t = s.get('text', '').strip()
                    if t:
                        texts.add(t)

    print(f'Processing {len(texts)} texts...')
    spans_by_text = {}
    total_spans = 0

    for t in sorted(texts):
        spans = parse_text_to_spans(t)
        if spans:
            spans_by_text[t] = spans
            total_spans += len(spans)

    print(f'Found {total_spans} static term spans across {len(spans_by_text)} texts.')

    # Write out Dart file
    out_dir = os.path.join('lib', 'features', 'rules', 'data')
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, 'static_glossary_spans.g.dart')

    with open(out_path, 'w', encoding='utf-8') as f:
        f.write('// GENERATED FILE - DO NOT MODIFY BY HAND\n')
        f.write('// Precomputed static recognition and linking of Munchkin rules glossary terms.\n')
        f.write('// Generated before app compilation to ensure zero runtime parsing overhead and 100% deterministic cross-platform behavior.\n\n')
        f.write("import '../domain/rules_glossary.dart';\n\n")
        f.write('abstract final class StaticGlossarySpans {\n')
        f.write('  static const Map<String, List<StaticSpan>> spansByText = {\n')

        for t, spans in spans_by_text.items():
            t_json = json.dumps(t, ensure_ascii=False)
            f.write(f'    {t_json}: [\n')
            for start, end, term_id in spans:
                f.write(f"      StaticSpan(start: {start}, end: {end}, termId: '{term_id}'),\n")
            f.write('    ],\n')

        f.write('  };\n')
        f.write('}\n')

    print(f'Successfully generated {out_path} ({os.path.getsize(out_path)} bytes)')

if __name__ == '__main__':
    main()
