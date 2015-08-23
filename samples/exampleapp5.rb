require "gtk3"

require "fileutils"

current_path = File.expand_path(File.dirname(__FILE__))
file_pattern = File.basename(__FILE__).gsub(".rb","")
DATA_PATH = "#{current_path}/data/#{file_pattern}"

gresource_bin = "#{DATA_PATH}/exampleapp.gresource"
gresource_xml = "#{DATA_PATH}/exampleapp.gresource.xml"

system("glib-compile-resources",
       "--target", gresource_bin,
       "--sourcedir", File.dirname(gresource_xml),
       gresource_xml)

gschema_bin = "#{DATA_PATH}/gschemas.compiled"
gschema_xml = "#{DATA_PATH}/org.gtk.exampleapp.gschema.xml"

system("glib-compile-schemas", DATA_PATH)


at_exit do
  FileUtils.rm_f([gresource_bin])
end

resource = Gio::Resource.load(gresource_bin)
Gio::Resources.register(resource)

Gio::SettingsSchemaSource.new(DATA_PATH,
                              Gio::SettingsSchemaSource.default,
                              false)

class ExampleAppWindow < Gtk::ApplicationWindow
  # https://github.com/ruby-gnome2/ruby-gnome2/pull/445
  # https://github.com/ruby-gnome2/ruby-gnome2/issues/503
  type_register
  class << self
    def init
      set_template(:resource => "/org/gtk/exampleapp/window.ui")
      bind_template_child("stack")
    end
  end

  def initialize(application)
    super(:application => application)
    # load settings from gschemas.compiled in a directory
    # see https://developer.gnome.org/gio/unstable/gio-GSettingsSchema-GSettingsSchemaSource.html#g-settings-schema-source-new-from-directory
    # check ruby-gnome Gio::Settings.new or Gio::Schemas ??
    settings = Gio::Settings.new("org.gtk.exampleapp")
    settings.bind("transition",
                  application.stack,
                  "transition-type",
                  Gio::SettingsBindFlags::DEFAULT)
  end

  def open(file)
    basename = file.basename
    scrolled = Gtk::ScrolledWindow.new
    scrolled.show
    scrolled.set_hexpand(true)
    scrolled.set_vexpand(true)
    view = Gtk::TextView.new
    view.set_editable(false)
    view.set_cursor_visible(false)
    view.show
    scrolled.add(view)
    stack.add_titled(scrolled, basename, basename)
    stream = file.read
    view.buffer.text = stream.read
  end
end

class ExampleApp < Gtk::Application
  def initialize
    super("org.gtk.exampleapp", :handles_open)

    signal_connect "startup" do |application|
      quit_accels = ["<Ctrl>Q"]
      action = Gio::SimpleAction.new("quit")
      action.signal_connect("activate") do |_action, parameter|
        application.quit
      end
      application.add_action(action)
      application.set_accels_for_action("app.quit", quit_accels)

      action = Gio::SimpleAction.new("preferences")
      action.signal_connect("activate") do |_action, parameter|

      end
      application.add_action(action)

      builder = Gtk::Builder.new(:resource => "/org/gtk/exampleapp/app-menu.ui")
      app_menu = builder.get_object("appmenu")
      application.set_app_menu(app_menu)

    end
    signal_connect "activate" do |application|
      window = ExampleAppWindow.new(application)
      window.present
    end

    signal_connect "open" do |application, files, hint|
      windows = application.windows
      win = nil
      unless windows.empty?
        win = windows.first
      else
        win = ExampleAppWindow.new(application)
      end

      files.each { |file| win.open(file) }

      win.present
    end

  end
end

app = ExampleApp.new

puts app.run([$0] + ARGV)
