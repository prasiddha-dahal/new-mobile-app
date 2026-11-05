"""Port pv-core-web's translation maps into Dart.

The web copy is the source of truth for wording, so mobile mirrors it rather
than re-translating. Run from the pv-core-mobile directory:

    python tool/port_translations.py ../pv-core-web
"""
import io, os, re, sys

HEADER = '''// GENERATED — do not edit by hand.
// Source: pv-core-web/src/translations/{src}
// Regenerate: python tool/port_translations.py ../pv-core-web
//
// Ported rather than re-translated so mobile and web say the same thing.
//
// ignore_for_file: prefer_single_quotes

const Map<String, Map<String, String>> {name} = {{
'''


def convert(src_path, name, out_path):
    body = io.open(src_path, encoding='utf-8').read().split('{', 1)[1]
    out, ns, keys = [HEADER.format(src=os.path.basename(src_path), name=name)], None, 0
    for line in body.splitlines():
        st = line.strip()
        if (not st or st.startswith('export') or st.startswith('} as const')
                or st.startswith('//') or st.startswith('/*')
                or st.startswith('*')):
            continue
        m = re.match(r'^([A-Za-z0-9_]+)\s*:\s*\{$', st)
        if m:
            if ns:
                out.append('  },\n')
            ns = m.group(1)
            out.append("  '%s': {\n" % ns)
            continue
        if st in ('},', '}', '};'):
            continue
        m = re.match(r'^([A-Za-z0-9_]+)\s*:\s*(".*")\s*,?$', st)
        if m:
            out.append("    '%s': %s,\n" % (m.group(1), m.group(2)))
            keys += 1
            continue
        raise SystemExit('UNPARSED in %s: %r' % (src_path, st))
    if ns:
        out.append('  },\n')
    out.append('};\n')
    io.open(out_path, 'w', encoding='utf-8', newline='\n').write(''.join(out))
    return keys


if __name__ == '__main__':
    web = sys.argv[1] if len(sys.argv) > 1 else '../pv-core-web'
    for src, name in (('en.ts', 'en'), ('ne.ts', 'ne')):
        n = convert(os.path.join(web, 'src/translations', src), name,
                    'lib/core/i18n/strings_%s.dart' % name)
        print('%s -> strings_%s.dart : %d keys' % (src, name, n))
