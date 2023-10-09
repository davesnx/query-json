[@deriving show({with_path: false})]
type regex = string;

[@deriving show({with_path: false})]
type literal =
  | Bool(bool) /* true */
  | String(string) /* "TEXT" */
  | Number(float) /* 123 or 123.0 */
  | Null; /* null */

[@deriving show({with_path: false})]
type expression =
  | Identity /* . */
  | Empty /* empty */
  | Pipe(expression, expression) /* | */
  | Comma(expression, expression) /* expr1 , expr2 */
  | Literal(literal)
  /* Constructors */
  | List(expression) /* [ expr ] */
  | Object(list((string, expression))) /* {} */
  /* Objects */
  | Walk(expression) /* walk() */
  | Transpose(expression) /* transpose() */
  | Key(string, bool) /* .foo */
  | Has(expression) /* has(x) */
  | Keys /* keys */
  | Floor /* floor */
  | Sqrt /* sqrt */
  | Type /* type */
  | Sort /* sort */
  | Min /* min */
  | Max /* max */
  | Unique /* unique */
  | Reverse /* reverse */
  | Explode /* explode */
  | Implode /* implode */
  | Any /* any */
  | All /* all */
  | In /* in */
  | Recurse /* recurse */
  | RecurseDown /* recurse_down */
  | ToEntries /* to_entries */
  | ToString /* to_string */
  | FromEntries /* from_entries */
  | WithEntries
  | Nan
  | IsNan
  /* Array */
  | Index(int) /* .[1] */
  | Iterator /* .[] */
  | IteratorWithRange(list(int)) /* .[] */
  | Range(int, int) /* range(1, 10) */
  | Flatten /* flatten */
  | Head /* head */
  | Tail /* tail */
  | Map(expression) /* .[] */ /* map(x) */
  | FlatMap(expression) /* flat_map(x) */
  | Reduce(expression) /* reduce(x) */
  | Select(expression) /* select(x) */
  | SortBy(expression) /* sort_by(x) */
  | GroupBy(expression) /* group_by(x) */
  | UniqueBy(expression) /* unique_by(x) */
  | MinBy(expression) /* min_by(x) */
  | MaxBy(expression) /* max_by(x) */
  | AllWithCondition(expression) /* all(c) */
  | AnyWithCondition(expression) /* any(c) */
  | Some_(expression) /* some, Some_ to not collide with option */
  | Find(expression) /* find(x) */
  /* operations */
  | Addition(expression, expression) /* + */
  | Subtraction(expression, expression) /* - */
  | Division(expression, expression) /* / */
  | Multiply(expression, expression) /* * */
  /* Generic */
  | Length /* length */
  | Contains(expression)
  /* Strings */
  | Test(regex)
  | ToNumber /* to_num */
  | StartsWith(expression) /* starts_with */
  | EndsWith(expression) /* ends_with */
  | Split(expression) /* split */
  | Join(expression) /* join */
  | Path(expression) /* path(x) */
  /* Logic */
  | If(expression)
  | Then(expression)
  | Else(expression)
  | Break
  /* Conditionals */
  | And(expression, expression) /* and */
  | Or(expression, expression) /* or */
  | Not /* not */
  | Greater(expression, expression) /* > */
  | Lower(expression, expression) /* < */
  | GreaterEqual(expression, expression) /* >= */
  | LowerEqual(expression, expression) /* <= */
  | Equal(expression, expression) /* == */
  | NotEqual(expression, expression); /* != */
