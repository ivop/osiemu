#include "toolswindow.h"
#include "ui_toolswindow.h"
#include <QFileDialog>

ToolsWindow::ToolsWindow(QWidget *parent) :
    QDialog(parent),
    ui(new Ui::ToolsWindow)
{
    ui->setupUi(this);
}

ToolsWindow::~ToolsWindow() {
    delete ui;
}

void ToolsWindow::on_button_input_eject_clicked() {
    command = "eject input";
    this->close();
}

void ToolsWindow::on_button_output_eject_clicked() {
    command = "eject output";
    this->close();
}

void ToolsWindow::on_button_input_rewind_clicked() {
    command = "rewind input";
    this->close();
}

void ToolsWindow::on_button_output_rewind_clicked() {
    command = "rewind output";
    this->close();
}

void ToolsWindow::on_button_drive0_unmount_clicked() {
    command = "unmount 0";
    this->close();
}

void ToolsWindow::on_button_drive1_unmount_clicked() {
    command = "unmount 1";
    this->close();
}

void ToolsWindow::on_button_drive2_unmount_clicked() {
    command = "unmount 2";
    this->close();
}

void ToolsWindow::on_button_drive3_unmount_clicked() {
    command = "unmount 3";
    this->close();
}

void ToolsWindow::insertTape(QString which) {
    QString filename = QFileDialog::getOpenFileName(this, "Select File", "", "Tape Files (*.bas *.lod);;All Files (*.*)");
    if (!filename.isEmpty()) {
        command = "insert " + which + " " + filename;
        this->close();
    }
}

void ToolsWindow::on_button_input_insert_clicked() {
    insertTape("input");
}

void ToolsWindow::on_button_output_insert_clicked() {
    insertTape("output");
}

void ToolsWindow::mountDisk(QString which) {
    QString filename = QFileDialog::getOpenFileName(this, "Select File", "", "Disk Images (*.os5 *.os8);;All Files (*.*)");
    if (!filename.isEmpty()) {
        command = "mount " + which + " " + filename;
        this->close();
    }
}

void ToolsWindow::on_button_drive0_mount_clicked() {
    mountDisk("0");
}

void ToolsWindow::on_button_drive1_mount_clicked() {
    mountDisk("1");
}

void ToolsWindow::on_button_drive2_mount_clicked() {
    mountDisk("2");
}

void ToolsWindow::on_button_drive3_mount_clicked() {
    mountDisk("3");
}
