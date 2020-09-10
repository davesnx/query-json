[@deriving show]
type regex = string;

[@deriving show]
type literal =
  | Bool(bool) /* true */
  | String(string) /* "TEXT" */
  | Number(float); /* 123 or 123.0 */

[@deriving show]
type expression =
  | Identity /* . */
  | Pipe(expression, expression) /* | */
  | Comma /* , */
  | Literal(literal)
  /* Constructors */
  | List /* [] */
  | Object /* {} */
  /* Objects */
  | Key(string) /* .foo */
  | Has(conditional) /* has(x) */
  | Keys /* keys */
  | ToEntries /* to_entries */
  /* Array */
  | Index(int) /* [1] */
  | Filter(conditional) /* .filter(x) */
  | Range(int, int) /* range(1, 10) */
  | Flatten /* flatten */
  | FlatMap /* flat_map | .[] */
  | Head /* head */
  | Tail /* tail */
  | Map(expression) /* .[] */ /* map(x) */
  | Select(expression) /* .select(x) */
  | SortBy(expression) /* sort_by(x) */
  | GroupBy(expression) /* group_by(x) */
  | FromEntries /* from_entries */
  | Sort /* sort */
  | Reverse /* reverse */
  | All(expression) /* all */
  | Any(expression) /* any */
  | Some(expression) /* some */
  | Find(expression) /* .find() */
  /* operations */
  | Addition(expression, expression) /* + */
  | Subtraction(expression, expression) /* - */
  | Division(expression, expression) /* / */
  | Multiply(expression, expression) /* * */
  /* Generic */
  | ToString /* to_string */
  | Type /* type */
  | Unique /* uniq */
  | Length /* length */
  | Contains
  /* Strings */
  | Test(regex)
  | StartsWith /* starts_with */
  | EndsWith /* ends_with */
  | Split /* split */
  | Join /* join */
  | ToNumber /* to_num */
  | And(conditional, conditional)
  | Or(conditional, conditional)
  | Xor(conditional, conditional)

and conditional =
  | Greater(expression, expression) /* > */
  | Lower(expression, expression) /* < */
  | GreaterEqual(expression, expression) /* >= */
  | LowerEqual(expression, expression) /* <= */
  | Equal(expression, expression) /* == */
  | NotEqual(expression, expression); /* != */
