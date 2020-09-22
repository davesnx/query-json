open Js_of_ocaml;

let n = 12;

let h = 20.;

let w = floor(h *. sqrt(3.) /. 2. +. 0.5);

/****/

Random.self_init();

let create_cubes = v =>
  Array.init(n, _ => Array.init(n, _ => Array.make(n, v)));

let get = (a, i, j, k) =>
  i < 0 || j < 0 || k < 0 || i < n && j < n && k < n && a[i][j][k];

let update = a => {
  let i = Random.int(n);
  let j = Random.int(n);
  let k = Random.int(n);
  if (a[i][j][k]) {
    if (!(get(a, i + 1, j, k) || get(a, i, j + 1, k) || get(a, i, j, k + 1))) {
      a[i][j][k] = false;
      true;
    } else {
      false;
    };
  } else if (get(a, i - 1, j, k)
             && get(a, i, j - 1, k)
             && get(a, i, j, k - 1)) {
    a[i][j][k] = true;
    true;
  } else {
    false;
  };
};

/****/

module Html = Dom_html;

let top = Js.string("#a8a8f6");

let left = Js.string("#d9d9d9");

let right = Js.string("#767676");

let edge = Js.string("#000000");

let on_cube = (c, i, j, k, f) => {
  let x = float(i - k + n - 1) *. w;
  let y = float(n - 1 - j) *. h +. float(i + k) *. h /. 2.;
  c##save;
  c##translate(x, y);
  f(c);
  c##restore;
};

let draw_top = c => {
  c##.fillStyle := top;
  c##beginPath;
  c##moveTo(w, 0.);
  c##lineTo(2. *. w, h /. 2.);
  c##lineTo(w, h);
  c##lineTo(0., h /. 2.);
  c##fill;
};

let top_edges = c => {
  c##beginPath;
  c##moveTo(0., h /. 2.);
  c##lineTo(w, 0.);
  c##lineTo(2. *. w, h /. 2.);
  c##stroke;
};

let draw_right = c => {
  c##.fillStyle := right;
  c##beginPath;
  c##moveTo(w, h);
  c##lineTo(w, 2. *. h);
  c##lineTo(2. *. w, 1.5 *. h);
  c##lineTo(2. *. w, h /. 2.);
  c##fill;
};

let right_edges = c => {
  c##beginPath;
  c##moveTo(w, 2. *. h);
  c##lineTo(w, h);
  c##lineTo(2. *. w, h /. 2.);
  c##stroke;
};

let draw_left = c => {
  c##.fillStyle := left;
  c##beginPath;
  c##moveTo(w, h);
  c##lineTo(w, 2. *. h);
  c##lineTo(0., 1.5 *. h);
  c##lineTo(0., h /. 2.);
  c##fill;
};

let left_edges = c => {
  c##beginPath;
  c##moveTo(w, h);
  c##lineTo(0., h /. 2.);
  c##lineTo(0., 1.5 *. h);
  c##stroke;
};

let remaining_edges = c => {
  c##beginPath;
  c##moveTo(0., float(n) *. 1.5 *. h);
  c##lineTo(float(n) *. w, float(n) *. 2. *. h);
  c##lineTo(float(n) *. 2. *. w, float(n) *. 1.5 *. h);
  c##lineTo(float(n) *. 2. *. w, float(n) *. 0.5 *. h);
  c##stroke;
};

let tile = (c, a, (top, right, left)) => {
  for (i in 0 to n - 1) {
    let j = ref(n - 1);
    for (k in 0 to n - 1) {
      while (j^ >= 0 && !a[i][j^][k]) {
        decr(j);
      };
      on_cube(c, i, j^, k, top);
    };
  };
  for (j in 0 to n - 1) {
    let i = ref(n - 1);
    for (k in 0 to n - 1) {
      while (i^ >= 0 && !a[i^][j][k]) {
        decr(i);
      };
      on_cube(c, i^, j, k, right);
    };
  };
  for (i in 0 to n - 1) {
    let k = ref(n - 1);
    for (j in 0 to n - 1) {
      while (k^ >= 0 && !a[i][j][k^]) {
        decr(k);
      };
      on_cube(c, i, j, k^, left);
    };
  };
};

let create_canvas = () => {
  let d = Html.window##.document;
  let c = Html.createCanvas(d);
  c##.width := n * 2 * truncate(w) + 1;
  c##.height := n * 2 * truncate(h) + 1;
  c;
};

let redraw = (ctx, canvas, a) => {
  let c = canvas##getContext(Html._2d_);
  c##setTransform(1., 0., 0., 1., 0., 0.);
  c##clearRect(0., 0., float(canvas##.width), float(canvas##.height));
  c##setTransform(1., 0., 0., 1., 0.5, 0.5);
  c##.globalCompositeOperation := Js.string("lighter");
  tile(c, a, (draw_top, draw_right, draw_left));
  c##.globalCompositeOperation := Js.string("source-over");
  tile(c, a, (top_edges, right_edges, left_edges));
  remaining_edges(c);
  ctx##drawImage_fromCanvas(canvas, 0., 0.);
};

let start = _ => {
  let c = create_canvas();
  let c' = create_canvas();
  Dom.appendChild(Html.window##.document##.body, c);
  let c = c##getContext(Html._2d_);
  c##.globalCompositeOperation := Js.string("copy");
  let a = create_cubes(true);
  redraw(c, c', a);
  Js._false;
};

Html.window##.onload := Html.handler(start);
