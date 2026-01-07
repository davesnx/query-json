(* MLX-compatible wrappers for Mosaic components.

   MLX passes children as a list, so we need wrappers that accept lists
   and convert them appropriately for the underlying Mosaic functions. *)

include Mosaic_mlx

(* input doesn't have children but MLX always passes them, so we ignore them *)
let input ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse ?on_key
    ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width ?inset
    ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap ?align_items
    ?align_self ?align_content ?justify_items ?justify_self ?justify_content
    ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink ?flex_basis
    ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?background ?text_color ?focused_background ?focused_text_color
    ?placeholder ?placeholder_color ?cursor_color ?cursor_style ?cursor_blinking
    ?max_length ?value ?autofocus ?on_input ?on_change ?on_submit ?children:_ ()
    =
  Mosaic.input ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse ?on_key
    ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width ?inset
    ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap ?align_items
    ?align_self ?align_content ?justify_items ?justify_self ?justify_content
    ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink ?flex_basis
    ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?background ?text_color ?focused_background ?focused_text_color
    ?placeholder ?placeholder_color ?cursor_color ?cursor_style ?cursor_blinking
    ?max_length ?value ?autofocus ?on_input ?on_change ?on_submit ()

(* Override text/code/markdown to accept children as a list and join them *)

let text ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse ?on_key
    ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width ?inset
    ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap ?align_items
    ?align_self ?align_content ?justify_items ?justify_self ?justify_content
    ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink ?flex_basis
    ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?style ?wrap_mode ?tab_indicator ?tab_indicator_color
    ?selection_bg ?selection_fg ?selectable ?(children = []) () =
  Mosaic_mlx.text ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse
    ?on_key ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width
    ?inset ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap
    ?align_items ?align_self ?align_content ?justify_items ?justify_self
    ?justify_content ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink
    ?flex_basis ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?style ?wrap_mode ?tab_indicator ?tab_indicator_color
    ?selection_bg ?selection_fg ?selectable
    ~children:(String.concat "" children)
    ()

let code ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse ?on_key
    ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width ?inset
    ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap ?align_items
    ?align_self ?align_content ?justify_items ?justify_self ?justify_content
    ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink ?flex_basis
    ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?filetype ?languages ?theme ?conceal ?draw_unstyled_text
    ?wrap_mode ?tab_width ?tab_indicator ?tab_indicator_color ?selection_bg
    ?selection_fg ?selectable ?(children = []) () =
  Mosaic_mlx.code ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse
    ?on_key ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width
    ?inset ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap
    ?align_items ?align_self ?align_content ?justify_items ?justify_self
    ?justify_content ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink
    ?flex_basis ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?filetype ?languages ?theme ?conceal ?draw_unstyled_text
    ?wrap_mode ?tab_width ?tab_indicator ?tab_indicator_color ?selection_bg
    ?selection_fg ?selectable
    ~children:(String.concat "" children)
    ()

let markdown ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse ?on_key
    ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width ?inset
    ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap ?align_items
    ?align_self ?align_content ?justify_items ?justify_self ?justify_content
    ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink ?flex_basis
    ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?style ?wrap_width ?paragraph_wrap ?block_quote_wrap ?headings
    ?code_blocks ?raw_html ?links ?images ?unknown_inline ?unknown_block
    ?languages ?(children = []) () =
  Mosaic_mlx.markdown ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse
    ?on_key ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width
    ?inset ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap
    ?align_items ?align_self ?align_content ?justify_items ?justify_self
    ?justify_content ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink
    ?flex_basis ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?style ?wrap_width ?paragraph_wrap ?block_quote_wrap ?headings
    ?code_blocks ?raw_html ?links ?images ?unknown_inline ?unknown_block
    ?languages
    ~children:(String.concat "" children)
    ()
