#ifndef TOOLSWINDOW_H
#define TOOLSWINDOW_H

#include <QDialog>

namespace Ui {
class ToolsWindow;
}

class ToolsWindow : public QDialog
{
    Q_OBJECT

public:
    explicit ToolsWindow(QWidget *parent = nullptr);
    ~ToolsWindow();
    QString command;

private slots:
    void on_button_input_eject_clicked();
    void on_button_output_eject_clicked();
    void on_button_input_rewind_clicked();
    void on_button_output_rewind_clicked();
    void on_button_drive0_unmount_clicked();
    void on_button_drive1_unmount_clicked();
    void on_button_drive2_unmount_clicked();
    void on_button_drive3_unmount_clicked();

    void on_button_input_insert_clicked();

    void on_button_output_insert_clicked();

    void on_button_drive0_mount_clicked();

    void on_button_drive1_mount_clicked();

    void on_button_drive2_mount_clicked();

    void on_button_drive3_mount_clicked();

private:
    Ui::ToolsWindow *ui;
    void insertTape(QString which);
    void mountDisk(QString which);
};

#endif // TOOLSWINDOW_H
