#include "mainwindow.h"
#include "../../version.h"
#include "consolewindow.h"
#include "ui_mainwindow.h"
#include <QDebug>
#include <QFileDialog>
#include <QMessageBox>

static const char *const magic = "OSIEMU-LAUNCHER!";

enum file_format_version {
    FILE_FORMAT_1 = 0
};

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);
    ui->version_string->setText(VERSION_STRING);
}

MainWindow::~MainWindow() {
    delete ui;
}

void MainWindow::generate_arguments(QStringList &arguments) {
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
    if (ui->check_pixels->checkState() == Qt::Checked) {
        arguments.append("--pixels");
    }
    if (ui->check_smooth_video->checkState() == Qt::Checked) {
        arguments.append("--smooth-video");
    }

    arguments.append("--frame-rate");
    switch (ui->combo_frame_rate->currentIndex()) {
    default:
        arguments.append("60");
        break;
    case 1:
        arguments.append("540bw");
        break;
    case 2:
        arguments.append("540col");
        break;
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
        arguments.append("quarter");
        break;
    case 1:
        arguments.append("half");
        break;
    case 2:
        arguments.append("510c-slow");
        break;
    case 3:
        arguments.append("510c-fast");
        break;
    case 4:
        arguments.append("540bw");
        break;
    case 5:
        arguments.append("540col");
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

    struct file_list_e {
        QString option;
        QString text_field;
    } file_list[] = {
        { "--kernel",      ui->line_kernel->text() },
        { "--basic",       ui->line_basic->text() },
        { "--font",        ui->line_font->text() },
        { "--graph-font",  ui->line_graphics_font->text() },
        { "--tape-input",  ui->line_tape_input->text() },
        { "--tape-output", ui->line_tape_output->text() },
        { "--floppy0",     ui->line_drive_a->text() },
        { "--floppy1",     ui->line_drive_b->text() },
        { "--floppy2",     ui->line_drive_c->text() },
        { "--floppy3",     ui->line_drive_d->text() }
    };

    for (const auto& x : file_list) {
        if (!x.text_field.isEmpty()) {
            arguments.append(x.option);
            arguments.append(x.text_field);
        }
    }

    // Switches
    QString switches;
    if (ui->check_disable_basic->checkState() == Qt::Checked) {
        switches += "nobasic,";
    }
    if (ui->check_enable_hires->checkState() == Qt::Checked) {
        switches += "hires,";
    }
    if (ui->check_enable_graph_font->checkState() == Qt::Checked) {
        switches += "graph,";
    }
    if (ui->check_start_fullscreen->checkState() == Qt::Checked) {
        switches += "fullscreen,";
    }

    if (!switches.isEmpty()) {
        arguments.append("--switches");
        arguments.append(switches.chopped(1));
    }

    // RAMTOP

    if (ui->check_force_ramtop->checkState() == Qt::Checked) {
        arguments.append("--force-ramtop");
        arguments.append(ui->combo_force_ramtop->currentText().split(QRegExp("\\s+")).at(0));
    }
}

void MainWindow::on_button_launch_clicked() {
    QString program = ui->line_program->text();
    QStringList arguments;

    this->hide();

    generate_arguments(arguments);

    auto *console = new ConsoleWindow(this, program, arguments);
    console->exec();

    this->show();
    delete(console);
}

void MainWindow::on_button_export_as_config_clicked() {
    QStringList arguments;

    generate_arguments(arguments);

    QMessageBox msg;

    QString filename = QFileDialog::getSaveFileName(this, "Export configuratian as...", "", "Configurations (*.config);;All Files (*.*)");
    if (filename.isEmpty()) return;

    QFile file(filename);
    if (!file.open(QIODevice::WriteOnly)) {
        msg.setText("Failed to open " + filename + "\n\n" + file.errorString());
        msg.exec();
        return;
    }

    QTextStream out(&file);

    bool first = true;

    for (const auto &i : qAsConst(arguments)) {
        // if( price1.at(0).toAscii() == '0')
        if (i.at(0).toLatin1() == '-' && i.at(1).toLatin1() == '-') {
            if (!first) {
                out << "\n";
            }
            out << i.toUtf8();
            first = false;
        } else {
            out << " " << i.toUtf8();
        }
    }
    out << "\n";

    auto error = file.error();
    auto errorstring = file.errorString();

    file.close();

    if (error != file.NoError) {
        msg.setText("Failed to save " + filename + "\n\n" + errorstring);
        msg.exec();
    }
}

void MainWindow::browse_all(QLineEdit *line, QString filter) {
    filter = filter + ";;All Files (*.*)";
    QString filename = QFileDialog::getOpenFileName(this, "Select File", "", filter);
    if (!filename.isEmpty()) {
        line->setText(filename);
    }
}

void MainWindow::on_browse_program_clicked() {
    browse_all(ui->line_program);
}

void MainWindow::on_browse_kernel_clicked() {
    browse_all(ui->line_kernel, "ROM Files (*.rom)");
}

void MainWindow::on_browse_basic_clicked() {
    browse_all(ui->line_basic, "ROM Files (*.rom)");
}

void MainWindow::on_browse_font_clicked() {
    browse_all(ui->line_font, "PNG Files (*.png)");
}

void MainWindow::on_browse_graphics_font_clicked() {
    browse_all(ui->line_graphics_font, "PNG Files (*.png)");
}

void MainWindow::on_browse_tape_input_clicked() {
    browse_all(ui->line_tape_input, "Tape Files (*.bas *.lod)");
}

void MainWindow::on_browse_tape_output_clicked() {
    browse_all(ui->line_tape_output, "");
}

void MainWindow::on_browse_drive_a_clicked() {
    browse_all(ui->line_drive_a, "Disk Images (*.os5 *.os8)");
}

void MainWindow::on_browse_drive_b_clicked() {
    browse_all(ui->line_drive_b, "Disk Images (*.os5 *.os8)");
}

void MainWindow::on_browse_drive_c_clicked() {
    browse_all(ui->line_drive_c, "Disk Images (*.os5 *.os8)");
}

void MainWindow::on_browse_drive_d_clicked() {
    browse_all(ui->line_drive_d, "Disk Images (*.os5 *.os8)");
}

void MainWindow::on_button_save_settings_clicked() {
    QMessageBox msg;

    QString filename = QFileDialog::getSaveFileName(this, "Save Settings To...", "", "Settings (*.settings);;All Files (*.*)");
    if (filename.isEmpty()) return;

    QFile file(filename);
    if (!file.open(QIODevice::WriteOnly)) {
        msg.setText("Failed to open " + filename + "\n\n" + file.errorString());
        msg.exec();
        return;
    }

    QDataStream out(&file);
    out.setVersion(QDataStream::Qt_5_15);

    out.writeRawData(magic, 16);

    out << (quint8) FILE_FORMAT_1;

    // serialize all settings
    // be careful when adding new settings, always add them at the end
    // even if that does not reflect how they are shown!

    out << ui->line_program->text();
    out << ui->line_kernel->text();
    out << ui->line_basic->text();
    out << ui->line_font->text();
    out << ui->line_graphics_font->text();
    out << ui->line_tape_input->text();
    out << ui->line_tape_output->text();
    out << ui->line_drive_a->text();
    out << ui->line_drive_b->text();
    out << ui->line_drive_c->text();
    out << ui->line_drive_d->text();

    out << (quint8) ui->combo_video_mode->currentIndex();
    out << (quint8) ui->combo_mono_color->currentIndex();
    out << (quint8) ui->combo_aspect->currentIndex();
    out << (quint8) ui->combo_zoom->currentIndex();
    out << (quint8) ui->combo_color_mode->currentIndex();
    out << (double) ui->spin_saturation->value();
    out << (quint8) ui->combo_hires->currentIndex();

    out << ui->check_scanlines->checkState();
    out << ui->check_smooth_video->checkState();

    out << (quint8) ui->combo_keyboard->currentIndex();
    out << (quint8) ui->combo_cooked_raw->currentIndex();
    out << ui->check_ascii_keyboard->checkState();

    out << ui->check_joystick_1->checkState();
    out << ui->check_joystick_2->checkState();
    out << (quint8) ui->spin_joystick_1->value();
    out << (quint8) ui->spin_joystick_2->value();

    out << (quint8) ui->combo_sound_mode->currentIndex();
    out << (quint16) ui->spin_sound_bufsize->value();

    out << (quint8) ui->combo_tape_baseclock->currentIndex();
    out << (quint8) ui->combo_tape_location->currentIndex();

    out << (quint8) ui->combo_cpu_speed->currentIndex();
    out << ui->check_warp_speed->checkState();
    out << ui->check_disable_basic->checkState();
    out << ui->check_enable_hires->checkState();
    out << ui->check_enable_graph_font->checkState();
    out << ui->check_start_fullscreen->checkState();
    out << ui->check_pixels->checkState();
    out << (quint8) ui->combo_frame_rate->currentIndex();
    out << ui->check_force_ramtop->checkState();
    out << (quint8) ui->combo_force_ramtop->currentIndex();

    auto error = file.error();
    auto errorstring = file.errorString();

    file.close();

    if (error != file.NoError) {
        msg.setText("Failed to save " + filename + "\n\n" + errorstring);
        msg.exec();
    }
}

void MainWindow::on_button_load_settings_clicked() {
    int error;
    QString errorstring;
    // temporary variables for deserialization
    QString tstring;
    quint8 t8;
    quint16 t16;
    double tdouble;
    Qt::CheckState tcs;

    QString filename = QFileDialog::getOpenFileName(this, "Load Settings From...", "", "Settings (*.settings);;All Files (*.*)");
    if (filename.isEmpty()) return;

    QMessageBox msg;

    QFile file(filename);
    if (!file.open(QIODevice::ReadOnly)) {
        msg.setText("Failed to open " + filename + "\n\n" + file.errorString());
        msg.exec();
        return;
    }

    QDataStream in(&file);
    in.setVersion(QDataStream::Qt_5_15);

    char checkmagic[16];
    in.readRawData(checkmagic, 16);
    if (memcmp(magic, checkmagic, 16) != 0) {
        error = QFile::OpenError;
        errorstring = "This is not an osiemu-launcher settings file";
        goto error_out;
    }

    quint8 file_format;
    in >> file_format;

    // In the future, use switch statement to call loaders for older version.
    // Saving will always save the latest version

    if (file_format != FILE_FORMAT_1) {
        error = QFile::OpenError;
        errorstring = "This settings file is from a newer version of osiemu-launcher!";
        goto error_out;
    }

    // deserialize all settings
    // same order as save settings, future settings always added to the end

    in >> tstring; ui->line_program->setText(tstring);
    in >> tstring; ui->line_kernel->setText(tstring);
    in >> tstring; ui->line_basic->setText(tstring);
    in >> tstring; ui->line_font->setText(tstring);
    in >> tstring; ui->line_graphics_font->setText(tstring);
    in >> tstring; ui->line_tape_input->setText(tstring);
    in >> tstring; ui->line_tape_output->setText(tstring);
    in >> tstring; ui->line_drive_a->setText(tstring);
    in >> tstring; ui->line_drive_b->setText(tstring);
    in >> tstring; ui->line_drive_c->setText(tstring);
    in >> tstring; ui->line_drive_d->setText(tstring);

    in >> t8; ui->combo_video_mode->setCurrentIndex(t8);
    in >> t8; ui->combo_mono_color->setCurrentIndex(t8);
    in >> t8; ui->combo_aspect->setCurrentIndex(t8);
    in >> t8; ui->combo_zoom->setCurrentIndex(t8);
    in >> t8; ui->combo_color_mode->setCurrentIndex(t8);
    in >> tdouble; ui->spin_saturation->setValue(tdouble);
    in >> t8; ui->combo_hires->setCurrentIndex(t8);

    in >> tcs; ui->check_scanlines->setCheckState(tcs);
    in >> tcs; ui->check_smooth_video->setCheckState(tcs);

    in >> t8; ui->combo_keyboard->setCurrentIndex(t8);
    in >> t8; ui->combo_cooked_raw->setCurrentIndex(t8);
    in >> tcs; ui->check_ascii_keyboard->setCheckState(tcs);

    in >> tcs; ui->check_joystick_1->setCheckState(tcs);
    in >> tcs; ui->check_joystick_2->setCheckState(tcs);
    in >> t8; ui->spin_joystick_1->setValue(t8);
    in >> t8; ui->spin_joystick_2->setValue(t8);

    in >> t8; ui->combo_sound_mode->setCurrentIndex(t8);
    in >> t16; ui->spin_sound_bufsize->setValue(t16);

    in >> t8; ui->combo_tape_baseclock->setCurrentIndex(t8);
    in >> t8; ui->combo_tape_location->setCurrentIndex(t8);

    in >> t8; ui->combo_cpu_speed->setCurrentIndex(t8);
    in >> tcs; ui->check_warp_speed->setCheckState(tcs);
    in >> tcs; ui->check_disable_basic->setCheckState(tcs);
    in >> tcs; ui->check_enable_hires->setCheckState(tcs);
    in >> tcs; ui->check_enable_graph_font->setCheckState(tcs);
    in >> tcs; ui->check_start_fullscreen->setCheckState(tcs);
    in >> tcs; ui->check_pixels->setCheckState(tcs);
    in >> t8; ui->combo_frame_rate->setCurrentIndex(t8);
    in >> tcs; ui->check_force_ramtop->setCheckState(tcs);
    in >> t8; ui->combo_force_ramtop->setCurrentIndex(t8);

    error = file.error();
    errorstring = file.errorString();

error_out:
    file.close();

    if (error != file.NoError) {
        msg.setText("Failed to load " + filename + "\n\n" + errorstring);
        msg.exec();
    }
}

