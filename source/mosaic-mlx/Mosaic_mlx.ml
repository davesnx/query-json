include Mosaic_tea

let null = Vnode.null
let raw = Vnode.raw
let input = Vnode.input
let canvas = Vnode.canvas
let table = Vnode.table
let slider = Vnode.slider
let select = Vnode.select
let spinner = Vnode.spinner
let tab_select = Vnode.tab_select
let scroll_bar = Vnode.scroll_bar
let markdown = Vnode.markdown
let fragment ?(children = []) () = Vnode.fragment children

let box ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse ?on_key
    ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width ?inset
    ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap ?align_items
    ?align_self ?align_content ?justify_items ?justify_self ?justify_content
    ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink ?flex_basis
    ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?background ?border ?border_sides ?border_style ?border_color
    ?focused_border_color ?should_fill ?custom_border_chars ?title
    ?title_alignment ?(children = []) () =
  Vnode.box ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse ?on_key
    ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width ?inset
    ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap ?align_items
    ?align_self ?align_content ?justify_items ?justify_self ?justify_content
    ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink ?flex_basis
    ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?background ?border ?border_sides ?border_style ?border_color
    ?focused_border_color ?should_fill ?custom_border_chars ?title
    ?title_alignment children

let scroll_box ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse ?on_key
    ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width ?inset
    ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap ?align_items
    ?align_self ?align_content ?justify_items ?justify_self ?justify_content
    ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink ?flex_basis
    ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?background ?scroll_x ?scroll_y ?scroll_acceleration
    ?sticky_scroll ?sticky_start ?viewport_culling ?autofocus ?on_scroll
    ?(children = []) () =
  Vnode.scroll_box ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse
    ?on_key ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width
    ?inset ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap
    ?align_items ?align_self ?align_content ?justify_items ?justify_self
    ?justify_content ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink
    ?flex_basis ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?background ?scroll_x ?scroll_y ?scroll_acceleration
    ?sticky_scroll ?sticky_start ?viewport_culling ?autofocus ?on_scroll
    children

let text ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse ?on_key
    ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width ?inset
    ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap ?align_items
    ?align_self ?align_content ?justify_items ?justify_self ?justify_content
    ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink ?flex_basis
    ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?text_style ?wrap_mode ?tab_indicator ?tab_indicator_color
    ?selection_bg ?selection_fg ?selectable content =
  Vnode.text ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse ?on_key
    ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width ?inset
    ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap ?align_items
    ?align_self ?align_content ?justify_items ?justify_self ?justify_content
    ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink ?flex_basis
    ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?text_style ?wrap_mode ?tab_indicator ?tab_indicator_color
    ?selection_bg ?selection_fg ?selectable content

let code ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse ?on_key
    ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width ?inset
    ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap ?align_items
    ?align_self ?align_content ?justify_items ?justify_self ?justify_content
    ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink ?flex_basis
    ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?filetype ?languages ?theme ?conceal ?draw_unstyled_text
    ?wrap_mode ?tab_width ?tab_indicator ?tab_indicator_color ?selection_bg
    ?selection_fg ?selectable content =
  Vnode.code ?id ?key ?visible ?z_index ?live ?buffer ?ref ?on_mouse ?on_key
    ?on_paste ?display ?box_sizing ?position ?overflow ?scrollbar_width ?inset
    ?size ?min_size ?max_size ?aspect_ratio ?margin ?padding ?gap ?align_items
    ?align_self ?align_content ?justify_items ?justify_self ?justify_content
    ?flex_direction ?flex_wrap ?flex_grow ?flex_shrink ?flex_basis
    ?grid_template_rows ?grid_template_columns ?grid_auto_rows
    ?grid_auto_columns ?grid_auto_flow ?grid_template_areas ?grid_row
    ?grid_column ?filetype ?languages ?theme ?conceal ?draw_unstyled_text
    ?wrap_mode ?tab_width ?tab_indicator ?tab_indicator_color ?selection_bg
    ?selection_fg ?selectable content
