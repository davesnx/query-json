[@deriving show]
type regex = string;

[@deriving show]
type literal =
  | Bool(bool) /* true */
  | String(string) /* "TEXT" */
  | Number(float) /* 123 or 123.0 */
  | Null; /* null */

[@deriving show]
type expression =
  | Identity /* . */
  | Pipe(expression, expression) /* | */
  | Comma /* , */
  | Literal(literal)
  /* Constructors */
  | List(list(expression)) /* [] */
  | Object(list((string, expression))) /* {} */
  /* Objects */
  | Walk(expression) /* walk() */
  | Transpose(expression) /* transpose() */
  | Key(string, bool) /* .foo */
  | Has(string) /* has(x) */
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
  | Index(int) /* [1] */
  | Filter(conditional) /* .filter(x) */
  | Range(int, int) /* range(1, 10) */
  | Flatten /* flatten */
  | Head /* head */
  | Tail /* tail */
  | Map(expression) /* .[] */ /* map(x) */
  | FlatMap(expression) /* flat_map */
  | Select(expression) /* .select(x) */
  | SortBy(expression) /* sort_by(x) */
  | GroupBy(expression) /* group_by(x) */
  | UniqueBy(expression) /* unique_by(x) */
  | MinBy(expression) /* min_by(x) */
  | MaxBy(expression) /* max_by(x) */
  | AllWithCondition(expression) /* all(c) */
  | AnyWithCondition(expression) /* any(c) */
  | Some(expression) /* some */
  | Find(expression) /* find(x) */
  /* operations */
  | Addition(expression, expression) /* + */
  | Subtraction(expression, expression) /* - */
  | Division(expression, expression) /* / */
  | Multiply(expression, expression) /* * */
  /* Generic */
  | Length /* length */
  | Contains(string)
  /* Strings */
  | Test(regex)
  | ToNumber /* to_num */
  | StartsWith(string) /* starts_with */
  | EndsWith(string) /* ends_with */
  | Split(string) /* split */
  | Join(string) /* join */
  | Path(expression) /* path(x) */
  /* Logic */
  | If(conditional)
  | Then(expression)
  | Else(expression)
  | Break

and conditional =
  | And(expression, expression) /* and */
  | Or(expression, expression) /* or */
  | Not(expression, expression) /* ! */
  | Greater(expression, expression) /* > */
  | Lower(expression, expression) /* < */
  | GreaterEqual(expression, expression) /* >= */
  | LowerEqual(expression, expression) /* <= */
  | Equal(expression, expression) /* == */
  | NotEqual(expression, expression); /* != */
