Map works in jq
  $ jq '.[]' <<< [1,2,3]
  1
  2
  3

Range access works in jq
  $ jq '.[1, 2]' <<< [1,2,3]
  2
  3

Map works
$ Bin --verbose '.[]' <<< [1,2,3]
1
2
3

Range access works in jq
$ Bin '.[1, 2]' <<< [1,2,3]

