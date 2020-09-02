[@deriving show]
type literal =
  | Bool(bool) /* true */
  | String(string) /* "TEXT" */
  | Number(float); /* 123 or 123.0 */

[@deriving show]
type expression =
  | Literal(literal)
  | Identity /* . */
  | Key(string) /* .foo */
  | Index(int) /* [1] */
  | Has(conditional) /* has(x) */
  | Filter(conditional) /* .filter(x) */
  | Addition(expression, expression) /* + */
  | Subtraction(expression, expression) /* - */
  | Division(expression, expression) /* / */
  | Multiply(expression, expression) /* * */
  | Pipe(expression, expression) /* | */
  | Range(int, int) /* range(1, 10) */
  | Keys /* keys */
  | Flatten /* flatten */
  | Head /* head */
  | Tail /* tail */
  | Length /* length */
  | List /* [] */
  | Object /* {} */
  | ToEntries /* to_entries */
  | FromEntries /* from_entries */
  | ToString /* to_string */
  | ToNumber /* to_num */
  | Type /* type */
  | Sort /* sort */
  | Unique /* uniq */
  | Reverse /* reverse */
  | StartsWith /* starts_with */
  | EndsWith /* ends_with */
  | Split /* split */
  | Join /* join */
  | Map(expression) /* .[] */ /* map(x) */
  | Select(expression) /* .select(x) */
  | SortBy(expression) /* sort_by(x) */
  | GroupBy(expression) /* group_by(x) */

and conditional =
  | Greater(expression, expression) /* > */
  | Lower(expression, expression) /* < */
  | GreaterEqual(expression, expression) /* >= */
  | LowerEqual(expression, expression) /* <= */
  | Equal(expression, expression) /* == */
  | NotEqual(expression, expression); /* != */
