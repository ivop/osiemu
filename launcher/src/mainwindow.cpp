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

    arguments.append("--mono-color");
    arguments.append(ui->combo_mono_color->currentText().toLower());

    arguments.append("--aspect");
    arguments.append(ui->combo_aspect->currentText().toLower());

    arguments.append("--zoom");
    arguments.append(ui->combo_zoom->currentText().toLower());

    arguments.append("--color-mode");
    switch (ui->combo_color_mode->currentIndex()) {
    default:
        arguments.append("monochrome");
        break;
    case 1:
        arguments.append("440b");
        break;
    case 2:
        arguments.append("540b");
        break;
    case 3:
        arguments.append("630");
        break;
    }

    arguments.append("--saturation");
    arguments.append(ui->spin_saturation->text().replace(",","."));  // always force period

    arguments.append("--hires-mode");
    switch (ui->combo_hires->currentIndex()) {
    default:
        arguments.append("none");
        break;
    case 1:
        arguments.append("440b");
        break;
    case 2:
        arguments.append("541");
        break;
    }

    if (ui->check_scanlines->checkState() == Qt::Checked) {
        arguments.append("--scanlines");
    }

    if (ui->check_smooth_video->checkState() == Qt::Checked) {
        arguments.append("--smooth-video");
    }

    ConsoleWindow *console = new ConsoleWindow(this, program, arguments);
    console->exec();

    this->show();
    delete(console);
}
