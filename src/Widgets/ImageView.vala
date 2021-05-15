/*
 *  Copyright 2019-2021 Tanaka Takayuki (田中喬之)
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Tanaka Takayuki <aharotias2@gmail.com>
 */

using Gdk, Gtk;

namespace Tatap {
    /**
     * Common interface of SingleImageView and DualImageView
     */
    public interface ImageView : Widget {
        /*
         * properties
         */
        public abstract ViewMode view_mode { get; construct; }
        public abstract Tatap.Window main_window { get; construct; }
        public abstract FileList file_list { get; set; }
        public abstract bool controllable { get; set; }
        public abstract string dir_path { owned get; }
        public abstract bool has_image { get; }
        public abstract double position { get; }
        public abstract int index { get; }

        /*
         * methods
         */
        public abstract File get_file() throws Error;
        public abstract bool is_next_button_sensitive();
        public abstract bool is_prev_button_sensitive();
        public abstract void go_forward(int offset = 1) throws Error;
        public abstract void go_backward(int offset = 1) throws Error;
        public abstract void open(File file) throws Error;
        public abstract void reopen() throws Error;
        public abstract void open_at(int index) throws Error;
        public abstract async void open_async(File file) throws Error;
        public abstract async void reopen_async() throws Error;
        public abstract async void open_at_async(int index) throws Error;
        public abstract void update_title();
        public abstract void update();
        public abstract void close();

        /*
         * signals
         */
        public signal void title_changed(string title);
        public signal void image_opened(string name, int index);
    }
}
