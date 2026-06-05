#include "my_application.h"

static gboolean is_empty_cursor_theme_message(const gchar* message) {
  return message != nullptr &&
         g_str_has_prefix(message, "Unable to load ") &&
         g_str_has_suffix(message, " from the cursor theme");
}

static void suppress_empty_cursor_theme_message(const gchar* log_domain,
                                                GLogLevelFlags log_level,
                                                const gchar* message,
                                                gpointer user_data) {
  if (is_empty_cursor_theme_message(message)) {
    return;
  }

  g_log_default_handler(log_domain, log_level, message, user_data);
}

static GLogWriterOutput suppress_empty_cursor_theme_writer(
    GLogLevelFlags log_level,
    const GLogField* fields,
    gsize n_fields,
    gpointer user_data) {
  for (gsize i = 0; i < n_fields; i++) {
    if (g_strcmp0(fields[i].key, "MESSAGE") == 0 &&
        is_empty_cursor_theme_message(
            static_cast<const gchar*>(fields[i].value))) {
      return G_LOG_WRITER_HANDLED;
    }
  }

  return g_log_writer_default(log_level, fields, n_fields, user_data);
}

int main(int argc, char** argv) {
  if (g_getenv("XCURSOR_THEME") == nullptr) {
    g_setenv("XCURSOR_THEME", "Adwaita", FALSE);
  }
  g_log_set_handler("Gdk", G_LOG_LEVEL_MESSAGE,
                    suppress_empty_cursor_theme_message, nullptr);
  g_log_set_writer_func(suppress_empty_cursor_theme_writer, nullptr, nullptr);
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
