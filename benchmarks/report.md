jq version: jq-1.6
q version: 0.2.1

## Select an attribute on small JSON files

### jq
```
"398eb027"
0.02 real         0.02 user         0.00 sys
```

### q
```
"398eb027"
0.01 real         0.00 user         0.00 sys
```

## Select an attribute on big JSON files

### jq
```
[ "features", "type" ]
6.21 real         5.57 user         0.62 sys
```

### q
```
[ "type", "features" ]
7.02 real         6.66 user         0.34 sys
```

## Bigger operation an attribute on small JSON file

### jq
```
[ 18.95, 22.990000000000002, 18.990000000000002, 32.989999999999995 ]
0.02 real         0.02 user         0.00 sys
```

### q
```
[ 18.95, 22.990000000000002, 18.990000000000002, 32.989999999999995 ]
0.00 real         0.00 user         0.00 sys
```

## Bigger operation an attribute on big JSON files

### jq
```
[...]
6.97 real         6.17 user         0.79 sys
```

### q
```
[...]
7.44 real         7.02 user         0.38 sys
```