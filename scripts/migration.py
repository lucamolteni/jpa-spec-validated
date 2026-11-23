"""Recheck the historical model and compare its canonical graphs to the baselines.

Usage: python3 scripts/migration.py --tlc /path/tla2tools.jar --tlapm /path/tlapm
The historical TLA+ files exist only in a temporary directory during this check.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def canonical_graph(path):
    nodes, edges = {}, []
    for line in Path(path).read_text().splitlines():
        match = re.match(r'(-?\d+) \[label="((?:\\.|[^"\\])*)"', line)
        if match:
            text = match[2].replace('\\"', '"').replace('\\n', '\n')
            life = re.findall(r'e[123] :> "(new|managed|detached|removed)"', text)
            ids = re.findall(r'e[123] :> (none|id1|id2)', text)
            created = re.search(r'createdEntities = \{([^}]*)\}', text)[1]
            assert len(life) == len(ids) == 3, text
            key = ';'.join(
                f'{int("e" + str(i + 1) in created)},'
                f'{["new", "managed", "detached", "removed"].index(life[i])},'
                f'{["none", "id1", "id2"].index(ids[i])}' for i in range(3))
            step = re.search(r'step = (\d+)', text)
            nodes[match[1]] = step[1] + '|' + key if step else key
        match = re.match(r'(-?\d+) -> (-?\d+)', line)
        if match:
            edges.append(match.groups())
    assert nodes, 'empty TLC graph'
    return sorted(set(nodes.values())), sorted({nodes[a] + '>' + nodes[b] for a, b in edges})


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tlc', type=Path, required=True)
    parser.add_argument('--tlapm', type=Path, required=True)
    args = parser.parse_args()
    record = json.loads((ROOT / 'verification/migration.json').read_text())
    tlc, tlapm = args.tlc.resolve(), args.tlapm.resolve()
    assert sha(tlc) == record['tools']['tlc']['jar_sha256'], 'TLC binary differs from recorded migration'
    assert sha(tlapm) == record['tools']['tlaps']['binary_sha256'], 'TLAPS binary differs from recorded migration'
    with tempfile.TemporaryDirectory(prefix='jpa-lifecycle-migration-') as directory:
        work = Path(directory)
        for name, digest in record['source_files'].items():
            content = subprocess.check_output(
                ['git', 'show', f'{record["original_revision"]}:{name}'], cwd=ROOT)
            assert hashlib.sha256(content).hexdigest() == digest, name
            (work / name).write_bytes(content)
        for name, module in [('lifecycle', 'EntityLifecycle'), ('scenario', 'EntityLifecycleScenarios')]:
            result = subprocess.run(['java', '-XX:+UseParallelGC', '-Xmx512m', '-cp', str(tlc),
                                     'tlc2.TLC', '-dump', 'dot,actionlabels', name + '.dot', module],
                                    cwd=work, capture_output=True, text=True, check=True)
            assert 'Model checking completed. No error has been found.' in result.stdout
            states, edges = canonical_graph(work / (name + '.dot'))
            for kind, values in [('states', states), ('edges', edges)]:
                expected = (ROOT / f'verification/{name}-{kind}.txt').read_text()
                assert '\n'.join(values) + '\n' == expected, f'{name}-{kind} changed'
            print(f'{name}: {len(states)} states and {len(edges)} edges match')
        result = subprocess.run([str(tlapm), '--strict', '--nofp', 'EntityLifecycle_proof.tla'],
                                cwd=work, capture_output=True, text=True, check=True)
        assert 'All 93 obligations proved.' in result.stdout + result.stderr
        print('TLAPS: all 93 obligations proved without cached proofs')


if __name__ == '__main__':
    main()
