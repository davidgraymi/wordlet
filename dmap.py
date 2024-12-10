import re

alpha = re.compile("[a-zA-Z]")
lines = []
with open("lib/dictionary/en1.dart") as f:
    lines = f.readlines()

for i in range(len(lines)-1, -1, -1):
    if (i != 0 and i != len(lines)-1):
        if len(lines[i]) != 6:
            lines.pop(i)
        elif len(alpha.findall(lines[i])) != 5:
            # print(lines[i])
            lines.pop(i)


with open("lib/dictionary/en1.5.dart", "w") as f:
    f.writelines(lines)
