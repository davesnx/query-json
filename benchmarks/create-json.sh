#!/usr/bin/env sh

name=${1:-'temp'}
size=${2:-399}
lastItem=$(($size + 1))
filename="benchmarks/"$name".json"

echo "[\n" > $filename;
for ((iter=0; iter<=$size; iter = iter + 1))
do
  echo '{ "time": ' "$iter" ' },\n' >> $filename;
done
echo '{ "time": ' "$lastItem" ' }\n' >> $filename;
echo ']' >> $filename;
