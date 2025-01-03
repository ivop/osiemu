#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QLineEdit>
#include <QMainWindow>

QT_BEGIN_NAMESPACE
namespace Ui { class MainWindow; }
QT_END_NAMESPACE

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(QWidget *parent = nullptr);
    ~MainWindow() override;

private slots:
    void on_button_launch_clicked();
    void on_browse_program_clicked();
    void on_browse_kernel_clicked();
    void on_browse_basic_clicked();
    void on_browse_font_clicked();
    void on_browse_graphics_font_clicked();
    void on_browse_tape_input_clicked();
    void on_browse_tape_output_clicked();
    void on_browse_drive_a_clicked();
    void on_browse_drive_b_clicked();
    void on_browse_drive_c_clicked();
    void on_browse_drive_d_clicked();
    void on_button_save_settings_clicked();
    void on_button_load_settings_clicked();
    void on_button_export_as_config_clicked();

private:
    Ui::MainWindow *ui;
    void browse_all(QLineEdit *line, QString filter = "");
    void generate_arguments(QStringList &arguments);
};
#endif // MAINWINDOW_H
