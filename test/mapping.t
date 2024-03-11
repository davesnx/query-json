  $ Bin '.first.pages' ./mock.json
  [
    {
      "id": 1,
      "title": "The Art of Flipping Coins",
      "url": "http://example.com/398eb027/1"
    },
    {
      "id": 2,
      "deleted": true
    },
    {
      "id": 3,
      "title": "Artichoke Salad",
      "url": "http://example.com/398eb027/3"
    },
    {
      "id": 4,
      "title": "Flying Bananas",
      "url": "http://example.com/398eb027/4"
    }
  ]

  $ Bin '.doesntexist' ./mock.json
  
  Error:  Trying to ".doesntexist" on an object, that don't have the field "doesntexist":
  { "first": ..., "second": ... }
  

TODO: This should trigger the same as above
  $ Bin '.doesnt_exist' ./mock.json

Error:  Trying to ".doesntexist" on an object, that don't have the field "doesntexist":
{ "first": ..., "second": ... }

