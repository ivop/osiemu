#include "mainwindow.h"
#include "ui_mainwindow.h"
#include <QDebug>
#include "consolewindow.h"

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);
}

MainWindow::~MainWindow()
{
    delete ui;
}


void MainWindow::on_button_launch_clicked()
{
    QString program;
    QStringList arguments;

    this->hide();

    QString tmp = "osiemu";

    tmp = ui->line_program->text();
    if (!tmp.isEmpty()) program = tmp;

    auto video_mode = ui->combo_video_mode->currentIndex();

    if (!video_mode) {
        arguments.append("--disable-video");
    } else {
        arguments.append("--video-mode");
        arguments.append(ui->combo_video_mode->currentText());
    }

    ConsoleWindow *console = new ConsoleWindow(this, program, arguments);
    console->exec();
    this->show();
    delete(console);
}
