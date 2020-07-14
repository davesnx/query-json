[@deriving show]
type identifier = string;

[@deriving show]
type literal =
  | String(string)
  | Float(float);

[@deriving show]
type expression =
  | Void
  | Literal(literal)
  | Identifier(identifier)
  | Apply(expression, list((string, expression)), expression)
  | Function(identifier, expression)
  | Binding((identifier, expression), expression);
