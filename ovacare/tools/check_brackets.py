from pathlib import Path
p=Path(r'd:\\Documents\\web\\ovacare\\ovacare\\lib\\main.dart')
s=p.read_text()
up_to=2516
lines=s.splitlines()
chunk='\n'.join(lines[:up_to])
counts={'(':chunk.count('('),')':chunk.count(')'), '[':chunk.count('['),']':chunk.count(']'), '{':chunk.count('{'),'}':chunk.count('}')}
print('Counts up to line',up_to)
for k,v in counts.items():
    print(k, v)
print('\nFirst 30 lines around error:')
for i,l in enumerate(lines[2496:2526], start=2497):
    print(f"{i:5}: {l}")
