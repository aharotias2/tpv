/*
 *  Copyright 2019-2021 Tanaka Takayuki (田中喬之)
 *
 *  This file is part of ParaPara.
 *
 *  ParaPara is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  ParaPara is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with ParaPara.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Tanaka Takayuki <aharotias2@gmail.com>
 */

using Gtk, Gdk;

/**
 * ParaParaWindow is a customized gtk window class.
 * This is the main window of ParaPara.
 */
namespace ParaPara {
    public class Window : Gtk.ApplicationWindow {
        private const IconSize ICON_SIZE = IconSize.SMALL_TOOLBAR;

        public bool repeat_updating_file_list { get; construct set; }
        public ParaPara.FileList? file_list { get; private set; default = null; }
        public ParaPara.ToolBar toolbar { get; private set; }
        public ToggleButton toolbar_toggle_button { get; private set; }
        public Revealer toolbar_revealer_above { get; private set; }
        public Revealer toolbar_revealer_below { get; private set; }
        public Revealer progress_revealer { get; private set; }
        public Scale progress_scale { get; private set; }
        public Label progress_label { get; private set; }
        public ImageView image_view { get; private set; }
        public ActionButton image_prev_button { get; private set; }
        public ActionButton image_next_button { get; private set; }
        
        public bool fullscreen_mode {
            get {
                return _fullscreen_mode;
            }
            set {
                _fullscreen_mode = value;
                action_fullscreen.set_state(new Variant.boolean(_fullscreen_mode));
                if (_fullscreen_mode) {
                    get_window().fullscreen();
                    toolbar.fullscreen_button.icon_name = "view-restore-symbolic";
                } else {
                    toolbar.fullscreen_button.icon_name = "view-fullscreen-symbolic";
                    get_window().unfullscreen();
                    image_view.reopen_async.begin((obj, res) => {
                        try {
                            image_view.reopen_async.end(res);
                        } catch (Error e) {
                            show_error_dialog(e.message);
                        }
                    });
                }
            }
        }

        public signal void require_new_window();
        public signal void require_quit();

        private Box header_buttons;
        private HeaderBar headerbar;
        private Revealer message_revealer;
        private Overlay window_overlay;
        private Label message_label;
        private Stack stack;
        private Box bottom_box;
        private Box below_box;
        private Box revealer_box;
        private Granite.Widgets.Welcome welcome;
        private bool _fullscreen_mode = false;
        private bool reveal_progress_flag = false;
        private bool menu_popped = false;
        private SimpleAction action_fullscreen;
        private SimpleAction action_toggle_toolbar;
        private SimpleAction action_save;
        private SimpleAction action_save_as;
        private bool is_open_when_value_changed = true;

        public Window(Gtk.Application app) {
            Object(
                application: app
            );
        }
                
        construct {
            init_action_map();
            
            /* the headerbar itself */
            headerbar = new HeaderBar() {
                show_close_button = true
            };
            {
                /* previous, next, open, and save buttons at the left of the headerbar */
                header_buttons = new Box(Orientation.HORIZONTAL, 5);
                {
                    var navigation_box = new Gtk.ButtonBox(Orientation.HORIZONTAL) {
                            layout_style = Gtk.ButtonBoxStyle.EXPAND };
                    {
                        image_prev_button = new ActionButton("go-previous-symbolic", _("Previous"), {"Left"}) {
                                sensitive = false };
                        {
                            image_prev_button.get_style_context().add_class("image_button");
                            image_prev_button.clicked.connect(() => {
                                is_open_when_value_changed = false;
                                int offset = 1;
                                if (image_view.view_mode == ViewMode.DUAL_VIEW_MODE) {
                                    offset = 2;
                                }
                                if (toolbar.sort_order == SortOrder.ASC) {
                                    image_view.go_backward_async.begin(offset);
                                } else {
                                    image_view.go_forward_async.begin(offset);
                                }
                            });
                        }

                        image_next_button = new ActionButton("go-next-symbolic", _("Next"), {"Right"}) {
                                sensitive = false };
                        {
                            image_next_button.get_style_context().add_class("image_button");
                            image_next_button.clicked.connect(() => {
                                is_open_when_value_changed = false;
                                int offset = 1;
                                if (image_view.view_mode == ViewMode.DUAL_VIEW_MODE) {
                                    offset = 2;
                                }
                                if (toolbar.sort_order == SortOrder.ASC) {
                                    image_view.go_forward_async.begin(offset);
                                } else {
                                    image_view.go_backward_async.begin(offset);
                                }
                            });
                        }

                        navigation_box.pack_start(image_prev_button);
                        navigation_box.pack_start(image_next_button);
                    }

                    header_buttons.pack_start(navigation_box, false, false);
                }

                var menu_button = new MenuButton();
                {
                    var menu_popover = new Popover(menu_button);
                    {
                        var menu = new GLib.Menu();
                        {
                            var new_section = new GLib.Menu();
                            {
                                var new_window_menuitem = new GLib.MenuItem(_("New"), "new");
                                new_section.append_item(new_window_menuitem);
                            }
                            
                            var file_section = new GLib.Menu();
                            {
                                var open_menuitem = new GLib.MenuItem(_("Open"), "open");
                                var save_menuitem = new GLib.MenuItem(_("Save"), "save(false)");
                                var save_as_menuitem = new GLib.MenuItem(_("Save as…"), "save(true)");
                                
                                file_section.append_item(open_menuitem);
                                file_section.append_item(save_menuitem);
                                file_section.append_item(save_as_menuitem);
                            }

                            var view_section = new GLib.Menu();
                            {
                                var view_mode_menu = new GLib.Menu();
                                {
                                    var single_menuitem = new GLib.MenuItem(_("Single View Mode"), "change-view-mode('single')");
                                    single_menuitem.set_icon(new ThemedIcon("view-paged-symbolic"));

                                    var slide_menuitem = new GLib.MenuItem(_("Scroll View Mode"), "change-view-mode('slide')");
                                    slide_menuitem.set_icon(new ThemedIcon("view-continuous-symbolic"));

                                    var dual_menuitem = new GLib.MenuItem(_("Dual View Mode"), "change-view-mode('dual')");
                                    dual_menuitem.set_icon(new ThemedIcon("view-dual-symbolic"));

                                    view_mode_menu.append_item(single_menuitem);
                                    view_mode_menu.append_item(slide_menuitem);
                                    view_mode_menu.append_item(dual_menuitem);
                                }
                                
                                var toggle_toolbar_menuitem = new GLib.MenuItem(_("Show Toolbar"), "toggletoolbar(true)");
                                var fullscreen_menuitem = new GLib.MenuItem(_("Full Screen"), "fullscreen(true)");
                                
                                view_section.append_submenu(_("Select View Mode"), view_mode_menu);
                                view_section.append_item(toggle_toolbar_menuitem);
                                view_section.append_item(fullscreen_menuitem);
                            }
                            
                            var info_section = new GLib.Menu();
                            {
                                var show_info_menuitem = new GLib.MenuItem(_("About…"), "show_info");
                                show_info_menuitem.set_icon(new ThemedIcon("com.github.aharotias2.parapara"));
                                info_section.append_item(show_info_menuitem);
                            }

                            menu.append_section(null, new_section);
                            menu.append_section(null, file_section);
                            menu.append_section(null, view_section);                           
                            menu.append_section(null, info_section);
                        }
                        
                        menu_popover.bind_model(menu, "win");
                        Idle.add(() => { menu_popover.sensitive = true; return false; });
                    }
                    
                    menu_button.image = new Gtk.Image.from_icon_name("open-menu-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
                    menu_button.clicked.connect(() => {
                        menu_popped = !menu_popped;
                    });
                    menu_button.popover = menu_popover;
                }
                
                headerbar.pack_start(header_buttons);
                headerbar.pack_end(menu_button);
            }

            /* switch welcome screen and image view */
            stack = new Stack() { transition_type = StackTransitionType.CROSSFADE };
            {
                /* welcome screen */
                welcome = new Granite.Widgets.Welcome(_("No Images Open"), _("Click 'Open Image' to get started."));
                {
                    welcome.append("document-open", _("Open Image"), _("Show and edit your image."));
                    welcome.activated.connect((i) => {
                        if (i == 0) {
                            on_open_button_clicked();
                        }
                    });
                }

                /* Add images and revealer into overlay */
                window_overlay = new Overlay();
                {
                    bottom_box = new Box(Orientation.VERTICAL, 0);
                    {
                        toolbar_revealer_below = new Revealer() {
                                transition_type = RevealerTransitionType.SLIDE_DOWN,
                                reveal_child = false };
                        {
                            var below_box = new Box(Orientation.VERTICAL, 0);
                            {
                                var dummy_button = new Button.from_icon_name("emblem-important-symbolic", SMALL_TOOLBAR);
                                below_box.pack_start(dummy_button);
                            }

                            toolbar_revealer_below.add(below_box);
                        }

                        /* image area in the center of the window */
                        image_view = new SingleImageView(this);
                        {
                            image_view.title_changed.connect((title) => {
                                headerbar.title = title;
                            });
                            image_view.image_opened.connect((name, index) => {
                                if (progress_scale.get_value() != (double) index) {
                                    is_open_when_value_changed = false;
                                    progress_scale.set_value((double) index);
                                    progress_label.label = _("Location: %d / %d (%d%%)").printf(
                                            index + 1, file_list.size, (int) ((double) index / (double) file_list.size * 100));
                                }
                            });

                            image_view.controllable = true;
                            image_view.events = ALL_EVENTS_MASK;
                        }

                        bottom_box.pack_start(toolbar_revealer_below, false, false);
                        bottom_box.pack_start(image_view as EventBox, true, true);
                    }

                    revealer_box = new Box(Orientation.VERTICAL, 0);
                    {
                        toolbar_revealer_above = new Revealer() {
                                transition_type = RevealerTransitionType.SLIDE_DOWN,
                                reveal_child = false };
                        {
                            /* contain buttons that can be opened from the menu */
                            toolbar = new ParaPara.ToolBar(this);
                            {
                                toolbar.sort_order_changed.connect(() => {
                                    image_next_button.sensitive = image_view.is_next_button_sensitive();
                                    image_prev_button.sensitive = image_view.is_prev_button_sensitive();
                                    image_view.reopen_async.begin((obj, res) => {
                                        try {
                                            image_view.reopen_async.end(res);
                                        } catch (Error e) {
                                            show_error_dialog(e.message);
                                        }
                                    });
                                    progress_scale.inverted = toolbar.sort_order == SortOrder.DESC;
                                });

                                toolbar.stick_button_clicked.connect((sticked) => {
                                    if (sticked) {
                                        below_box.height_request = toolbar.height_request;
                                        toolbar_revealer_below.reveal_child = true;
                                        toolbar_toggle_button.sensitive = false;
                                    } else {
                                        toolbar_revealer_above.reveal_child = true;
                                        toolbar_revealer_below.reveal_child = false;
                                        toolbar_toggle_button.sensitive = true;
                                    }
                                });

                                toolbar.view_mode_changed.connect((view_mode) => {
                                    try {
                                        update_image_view(view_mode);
                                    } catch (Error error) {
                                        show_error_dialog(error.message);
                                    }
                                });
                            }

                            toolbar_revealer_above.add(toolbar);
                        }

                        message_revealer = new Revealer() {
                                transition_type = RevealerTransitionType.SLIDE_UP,
                                transition_duration = 100, reveal_child = false };
                        {
                            var message_bar = new Box(Orientation.HORIZONTAL, 0) {
                                    valign = Align.END, hexpand = true, vexpand = false };
                            {
                                /* revealer showing error messages */
                                message_label = new Label("") {
                                        margin = 10 };
                                {
                                    message_label.get_style_context().add_class("message_label");
                                }

                                message_bar.pack_start(message_label);
                                message_bar.get_style_context().add_class("message_bar");
                            }

                            message_revealer.add(message_bar);
                        }

                        progress_revealer = new Revealer() {
                                transition_type = RevealerTransitionType.SLIDE_UP,
                                transition_duration = 200, reveal_child = false };
                        {
                            var progress_box = new Box(Orientation.VERTICAL, 0);
                            {
                                progress_scale = new Scale.with_range(Orientation.HORIZONTAL, 0.0, 1.0, 0.1) {
                                        draw_value = false, has_origin = true, margin = 5 };
                                {
                                    progress_scale.change_value.connect((scroll_type, new_value) => {
                                        debug("progress_scale.change_value(%f)", progress_scale.get_value());
                                        debug("progress_adjustment %f, %f", progress_scale.adjustment.upper, progress_scale.adjustment.lower);
                                    });
                                    
                                    progress_scale.value_changed.connect(() => {
                                        debug("progress_scale.value_changed => (%f)", progress_scale.get_value());
                                        if (is_open_when_value_changed) {
                                            switch (image_view.view_mode) {
                                              default:
                                              case SINGLE_VIEW_MODE:
                                              case DUAL_VIEW_MODE:
                                                int index = (int) progress_scale.get_value();
                                                image_view.open_at_async.begin(index, (obj, res) => {
                                                    try {
                                                        image_view.open_at_async.end(res);
                                                        progress_label.label = _("Location: %d / %d (%d%%)").printf(
                                                                index + 1, file_list.size, (int) ((double) index / (double) file_list.size * 100));
                                                    } catch (Error e) {
                                                        show_error_dialog(e.message);
                                                    }
                                                });
                                                break;
                                              case SLIDE_VIEW_MODE:
                                                var view = image_view as SlideImageView;
                                                view.set_location(progress_scale.get_value());
                                                break;
                                            }
                                        } else {
                                            is_open_when_value_changed = true;
                                        }
                                    });
                                }

                                progress_label = new Label("");

                                progress_box.pack_start(progress_scale, false, false);
                                progress_box.pack_start(progress_label, false, false);
                                progress_box.get_style_context().add_class("progress_bar");
                            }

                            progress_revealer.add(progress_box);
                        }

                        revealer_box.pack_start(toolbar_revealer_above, false, false);
                        revealer_box.pack_end(message_revealer, false, false);
                        revealer_box.pack_end(progress_revealer, false, false);
                    }

                    window_overlay.add(bottom_box);
                    window_overlay.add_overlay(revealer_box);
                    window_overlay.set_overlay_pass_through(revealer_box, true);
                }

                stack.add_named(welcome, "welcome");
                stack.add_named(window_overlay, "picture");
            }

            add(stack);

            set_titlebar(headerbar);
            set_default_size(800, 600);
            add_events(Gdk.EventMask.SCROLL_MASK);
            destroy.connect(() => {
                if (file_list != null) {
                    file_list.close();
                }
                image_view.close();
            });

            setup_css();
        }

        private void init_action_map() {
            var action_new = new SimpleAction("new", null);
            action_new.activate.connect(() => {
                require_new_window();
            });
            add_action(action_new);
            
            var action_open = new SimpleAction("open", null);
            action_open.activate.connect(() => {
                on_open_button_clicked();
            });
            add_action(action_open);
            
            action_save = new SimpleAction("save", VariantType.BOOLEAN);
            action_save.activate.connect((param) => {
                if (image_view.view_mode == SINGLE_VIEW_MODE) {
                    var single_image_view = image_view as SingleImageView;
                    bool save_mode = param.get_boolean();
                    single_image_view.save_file_async.begin(save_mode);
                } else {
                    print("Save action was activated\n");
                }
            });
            add_action(action_save);

            action_toggle_toolbar = new SimpleAction.stateful("toggletoolbar", VariantType.BOOLEAN, new Variant.boolean(false));
            action_toggle_toolbar.activate.connect((param) => {
                bool state = action_toggle_toolbar.get_state().get_boolean();
                state = !state;
                action_toggle_toolbar.set_state(new Variant.boolean(state));
                toolbar_revealer_above.reveal_child = state;
            });
            action_toggle_toolbar.set_state(new Variant.boolean(false));
            add_action(action_toggle_toolbar);
            
            var action_show_info = new SimpleAction("show_info", null);
            action_show_info.activate.connect(() => {
                show_app_dialog(this);
            });
            add_action(action_show_info);
            
            var action_change_view_mode = new SimpleAction.stateful("change-view-mode", VariantType.STRING, new Variant.string("single"));
            action_change_view_mode.activate.connect((param) => {
                if (stack.visible_child_name != "picture") {
                    return;
                }
                try {
                    action_change_view_mode.set_state(param);
                    ViewMode view_mode = SINGLE_VIEW_MODE;
                    switch (param.get_string()) {
                      case "single":
                        view_mode = SINGLE_VIEW_MODE;
                        action_save.set_enabled(true);
                        action_save_as.set_enabled(true);
                        break;
                      case "slide":
                        view_mode = SLIDE_VIEW_MODE;
                        action_save.set_enabled(false);
                        action_save_as.set_enabled(false);
                        break;
                      case "dual":
                        view_mode = DUAL_VIEW_MODE;
                        action_save.set_enabled(false);
                        action_save_as.set_enabled(false);
                        break;
                    }
                    toolbar.view_mode = view_mode;
                    update_image_view(view_mode);
                } catch (Error error) {
                    show_error_dialog(error.message);
                }
            });
            action_change_view_mode.set_state(new Variant.string("single"));
            add_action(action_change_view_mode);
            
            action_fullscreen = new SimpleAction.stateful("fullscreen", VariantType.BOOLEAN, new Variant.boolean(false));
            action_fullscreen.activate.connect((param) => {
                bool state = action_fullscreen.get_state().get_boolean();
                state = !state;
                fullscreen_mode = state;
            });
            action_fullscreen.set_state(new Variant.boolean(false));
            add_action(action_fullscreen);
        }

        private bool in_progress_area(double x, double y) {
            int win_x_root, win_y_root;
            get_window().get_origin(out win_x_root, out win_y_root);
            Allocation allocation;
            get_allocation(out allocation);
            return (win_y_root + allocation.height * 0.8) < ((int) y) <= win_y_root + allocation.height;
        }

        private bool in_toolbar_area(double x, double y) {
            int win_x_root, win_y_root;
            get_window().get_origin(out win_x_root, out win_y_root);
            Allocation allocation;
            get_allocation(out allocation);
            return win_y_root <= (y - allocation.y) <= win_y_root + allocation.height * 0.2;
        }

        public override bool motion_notify_event(EventMotion ev) {
            if (stack.visible_child_name == "picture") {
                if (in_progress_area(ev.x_root, ev.y_root)) {
                    if (!progress_revealer.child_revealed) {
                        reveal_progress_flag = true;
                        Timeout.add(300, () => {
                            if (reveal_progress_flag) {
                                progress_revealer.reveal_child = true;
                                window_overlay.set_overlay_pass_through(revealer_box, false);
                                reveal_progress_flag = false;
                            }
                            return false;
                        });
                    }
                } else {
                    reveal_progress_flag = false;
                    if (progress_revealer.child_revealed) {
                        Timeout.add(300, () => {
                            progress_revealer.reveal_child = false;
                            window_overlay.set_overlay_pass_through(revealer_box, true);
                            return false;
                        });
                    }
                }
                if (!menu_popped && !action_toggle_toolbar.get_state().get_boolean()) {
                    if (in_toolbar_area(ev.x_root, ev.y_root)) {
                        if (!toolbar_revealer_above.child_revealed) {
                            Timeout.add(300, () => {
                                toolbar_revealer_above.reveal_child = true;
                                return false;
                            });
                        }
                    } else {
                        if (toolbar_revealer_above.child_revealed) {
                            Timeout.add(300, () => {
                                toolbar_revealer_above.reveal_child = false;
                                return false;
                            });
                        }
                    }
                }
            }
            return false;
        }

        public override bool leave_notify_event(EventCrossing ev) {
            reveal_progress_flag = false;
            if (progress_revealer.child_revealed) {
                Timeout.add(300, () => {
                    progress_revealer.reveal_child = false;
                    window_overlay.set_overlay_pass_through(revealer_box, true);
                    return false;
                });
            }
            return false;
        }

        public override bool key_press_event(EventKey ev) {
            if (Gdk.ModifierType.CONTROL_MASK in ev.state) {
                switch (ev.keyval) {
                  case Gdk.Key.m:
                    if (toolbar_toggle_button.sensitive) {
                        toolbar_toggle_button.active = !toolbar_toggle_button.active;
                        toolbar_toggle_button.toggled();
                    }
                    break;
                  case Gdk.Key.f:
                    if (toolbar_revealer_above.child_revealed && !toolbar.sticked) {
                        toolbar_toggle_button.active = true;
                        toolbar.stick_toolbar();
                    } else if (toolbar_revealer_below.child_revealed) {
                        toolbar.unstick_toolbar();
                    }
                    break;
                  case Gdk.Key.n:
                    require_new_window();
                    break;
                  case Gdk.Key.o:
                    on_open_button_clicked();
                    break;
                  case Gdk.Key.w:
                    close();
                    break;
                  case Gdk.Key.q:
                    require_quit();
                    break;
                }
            } else {
                switch (ev.keyval) {
                  case Gdk.Key.F11:
                    fullscreen_mode = !fullscreen_mode;
                    break;
                  default: break;
                }
            }
            if (stack.visible_child_name == "picture") {
                return image_view.key_press_event(ev);
            } else {
                return false;
            }
        }

        public override bool scroll_event(EventScroll ev) {
            if (stack.visible_child_name == "picture" && WidgetUtils.is_event_in_widget((Event) ev, image_view as Widget)) {
                return image_view.scroll_event(ev);
            } else {
                return false;
            }
        }

        private void setup_css() {
            var css_provider = new CssProvider();
            css_provider.load_from_resource ("/com/github/aharotias2/parapara/Application.css");
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),
                    css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        public void on_open_button_clicked() {
            var dialog = new Gtk.FileChooserDialog(_("Choose file to open"), this, Gtk.FileChooserAction.OPEN,
                    _("Cancel"), Gtk.ResponseType.CANCEL, _("Open"), Gtk.ResponseType.ACCEPT);
            if (file_list != null) {
                dialog.set_current_folder(file_list.dir_path);
            }
            int res = dialog.run();
            if (res == Gtk.ResponseType.ACCEPT) {
                var file_path = dialog.get_filename();
                File file = File.new_for_path(file_path);
                open_file_async.begin(file);
            }
            dialog.close();
        }

        public async void open_file_async(File file) {
            string? old_file_dir = null;
            if (file_list != null) {
                old_file_dir = file_list.dir_path;
            }

            try {
                if (old_file_dir == null || old_file_dir != file.get_parent().get_path()) {
                    if (file_list != null) {
                        file_list.close();
                    }
                    file_list = new ParaPara.FileList.with_dir_path(file.get_parent().get_path());
                    file_list.directory_not_found.connect(() => {
                        show_error_dialog(_("The directory does not found. Exiting."));
                        stack.visible_child_name = "welcome";
                    });
                    file_list.file_not_found.connect(() => {
                        show_error_dialog(_("The file does not found."));
                    });
                    file_list.updated.connect(() => {
                        image_view.update();
                        progress_scale.set_range(0.0, (double) (file_list.size - 1));
                        progress_scale.set_value(image_view.index);
                        progress_label.label = _("Location: %d / %d (%d%%)").printf(image_view.index + 1, file_list.size, (int) (image_view.position * 100));
                    });
                    file_list.terminated.connect(() => {
                        if (repeat_updating_file_list) {
                            image_prev_button.sensitive = false;
                            image_next_button.sensitive = false;
                        }
                    });
                    file_list.make_list_async.begin(repeat_updating_file_list, (obj, res) => {
                        if (image_view.view_mode != ViewMode.SINGLE_VIEW_MODE) {
                            disable_controls();
                            image_view.open_async.begin(file, (obj, res) => {
                                try {
                                    image_view.open_async.end(res);
                                    image_view.update_title();
                                } catch (Error e) {
                                    show_error_dialog(e.message);
                                }
                                enable_controls();
                            });
                        }
                    });
                    image_view.file_list = file_list;
                    image_prev_button.sensitive = false;
                    image_next_button.sensitive = false;
                }

                if (image_view.view_mode == SINGLE_VIEW_MODE || file_list.has_list) {
                    disable_controls();
                    yield image_view.open_async(file);
                    enable_controls();
                    image_view.update_title();
                }

                if (image_view.view_mode == SINGLE_VIEW_MODE) {
                    toolbar.animation_play_pause_button.icon_name = "media-playback-start-symbolic";
                }
                stack.visible_child_name = "picture";
            } catch (Error e) {
                string message;
                if (e is AppError) {
                    message = e.message;
                } else {
                    message = _("The file could not be opend (cause: %s)").printf(e.message);
                }
                show_error_dialog(message);
                enable_controls();
                if (!image_view.has_image) {
                    stack.visible_child_name = "welcome";
                }
            }
        }

        public async void show_message_async(string message) {
            Idle.add(show_message_async.callback);
            yield;
            message_label.label = message;
            message_revealer.reveal_child = true;
            Timeout.add(2000, show_message_async.callback);
            yield;
            message_revealer.reveal_child = false;
        }

        public void update_image_view(ViewMode view_mode) throws Error {
            if (image_view.view_mode != view_mode) {
                File file = image_view.get_file();
                bottom_box.remove(image_view);
                switch (view_mode) {
                  case SINGLE_VIEW_MODE:
                    image_view = new SingleImageView.with_file_list(this, file_list);
                    break;
                  case DUAL_VIEW_MODE:
                    image_view = new DualImageView.with_file_list(this, file_list);
                    break;
                  case SLIDE_VIEW_MODE:
                    image_view = new SlideImageView.with_file_list(this, file_list);
                    break;
                }
                bottom_box.pack_start(image_view as EventBox, true, true);
                image_view.title_changed.connect((title) => {
                    headerbar.title = title;
                });
                image_view.image_opened.connect((name, index) => {
                    is_open_when_value_changed = false;
                    if (progress_scale.get_value() != (double) index) {
                        progress_scale.set_value((double) index);
                        progress_label.label = _("Location: %d / %d (%d%%)").printf(
                                index + 1, file_list.size, (int) ((double) index / (double) file_list.size * 100));
                    }
                });
                image_view.controllable = true;
                image_view.events = ALL_EVENTS_MASK;
                open_file_async.begin(file);
                bottom_box.show_all();
            }
        }

        public void show_error_dialog(string message) {
            MessageDialog alert = new MessageDialog(this, DialogFlags.MODAL, MessageType.ERROR, ButtonsType.OK, message);
            alert.run();
            alert.close();
        }

        public void disable_controls() {
            headerbar.sensitive = false;
            toolbar.sensitive = false;
            image_view.controllable = false;
        }

        public void enable_controls() {
            headerbar.sensitive = true;
            toolbar.sensitive = true;
            image_view.controllable = true;
        }

        public void show_app_dialog(Window parent_window) {
            var dialog = new AboutDialog();
            dialog.set_destroy_with_parent(true);
            dialog.set_transient_for(parent_window);
            dialog.set_modal(true);
            dialog.artists = {"Nararyans R.I. @Fatih20"};
            dialog.authors = {"Takayuki Tanaka @aharotias2", "Ryo Nakano @ryonakano"};
            dialog.documenters = null;
            dialog.translator_credits = null;
            dialog.program_name = "ParaPara";
            dialog.comments = "A lightweight image viewer with three display modes: single, spread, and continuous.";
            dialog.copyright = "Copyright (C) 2020-2021 Takayuki Tanaka";
            dialog.version = "3.0.0";
            dialog.license =
"""This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.""";
            dialog.wrap_license = true;
            dialog.website = "https://github.com/aharotias2/parapara";
            dialog.website_label = "ParaPara @ Github";
            dialog.logo_icon_name = "com.github.aharotias2.parapara";
            dialog.response.connect((response_id) => {
                if (response_id == ResponseType.CANCEL || response_id == ResponseType.DELETE_EVENT) {
                    dialog.hide_on_delete();
                }
            });
            dialog.present();
        }
    }
}
