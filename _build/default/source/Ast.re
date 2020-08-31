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
  | Map(expression) /* .[] */ /* map(x) */
  | Filter(conditional) /* .filter(x) */
  | Select(expression) /* .select(x) */
  | Index(int) /* [1] */
  | Addition(expression, expression) /* + */
  | Subtraction(expression, expression) /* - */
  | Division(expression, expression) /* / */
  | Multiply(expression, expression) /* * */
  | Pipe(expression, expression) /* | */
  | Keys /* keys */
  | Flatten /* flatten */
  | Head /* head */
  | Tail /* tail */
  | Length /* length */
  /* Not implemented */
  | List /* [] */
  | Object /* {} */
  | ToEntries /* to_entries */
  | FromEntries /* from_entries */
  | Has(string) /* has(x) */
  | Range(int, int) /* range(1, 10) */
  | ToString /* to_string */
  | ToNumber /* to_num */
  | Type /* type */
  | Sort /* sort */
  | SortBy(expression) /* sort_by(x) */
  | GroupBy(expression) /* group_by(x) */
  | Unique /* uniq */
  | Reverse /* reverse */
  | StartsWith /* starts_with */
  | EndsWith /* ends_with */
  | Split /* split */
  | Join /* join */
and conditional =
  | GT(expression, expression) /* Greater > */
  | LT(expression, expression) /* Lower < */
  | GTE(expression, expression) /* Greater equal >= */
  | LTE(expression, expression) /* Lower equal <= */
  | EQ(expression, expression) /* equal == */
  | NOT_EQ(expression, expression); /* not equal != */
