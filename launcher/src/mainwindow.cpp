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

    // Program

    QString tmp = "osiemu";

    tmp = ui->line_program->text();
    if (!tmp.isEmpty()) program = tmp;

    // Video

    if (!ui->combo_video_mode->currentIndex()) {
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

    // Keyboard

    if (ui->combo_keyboard->currentIndex() == 0) {
        arguments.append("--invert-keyboard");
    }
    if (ui->combo_cooked_raw->currentIndex() == 1) {
        arguments.append("--raw-keyboard");
    }
    if (ui->check_ascii_keyboard->checkState() == Qt::Checked) {
        arguments.append("--ascii-keyboard");
    }

    // Joysticks

    if (ui->check_joystick_1->checkState() == Qt::Checked) {
        arguments.append("--joystick1");
        arguments.append(ui->spin_joystick_1->text());
    }
    if (ui->check_joystick_2->checkState() == Qt::Checked) {
        arguments.append("--joystick2");
        arguments.append(ui->spin_joystick_2->text());
    }

    // Sound

    arguments.append("--sound-mode");

    switch (ui->combo_sound_mode->currentIndex()) {
    default:
        arguments.append("none");
        break;
    case 1:
        arguments.append("542b");
        break;
    case 2:
        arguments.append("600");
        break;
    }

    arguments.append("--sound-bufsize");
    arguments.append(ui->spin_sound_bufsize->text());

    // Clocks

    arguments.append("--cpu-speed");

    switch (ui->combo_cpu_speed->currentIndex()) {
    default:
        arguments.append("c1p");
        break;
    case 1:
        arguments.append("510c-slow");
        break;
    case 2:
        arguments.append("510c-fast");
        break;
    case 3:
        arguments.append("uk101");
        break;
    case 4:
        arguments.append("c2p");
        break;
    }

    if (ui->check_warp_speed->checkState() == Qt::Checked) {
        arguments.append("--warp-speed");
    }

    // Tape

    unsigned int baseclock;
    switch (ui->combo_tape_baseclock->currentIndex()) {
    default:    baseclock =   4800; break;
    case 1:     baseclock =   9600; break;
    case 2:     baseclock =  19200; break;
    case 3:     baseclock =  38400; break;
    case 4:     baseclock =  76800; break;
    case 5:     baseclock = 153600; break;
    }
    arguments.append("--tape-baseclock");
    arguments.append(QString::number(baseclock));

    arguments.append("--tape-location");
    arguments.append(ui->combo_tape_location->currentText());

    // Files
    // TODO

    ConsoleWindow *console = new ConsoleWindow(this, program, arguments);
    console->exec();

    this->show();
    delete(console);
}
