#include "consolewindow.h"
#include "toolswindow.h"
#include "ui_consolewindow.h"
#include <QDebug>
#include <QFileInfo>
#include <QProcess>

ConsoleWindow::ConsoleWindow(QWidget *parent, const QString& program, const QStringList& arguments) :
    QDialog(parent),
    ui(new Ui::ConsoleWindow)
{
    ui->setupUi(this);
    this->setWindowFlags(Qt::Window);

    process = new QProcess(this);

    connect(process, &QProcess::started, this, &ConsoleWindow::processStarted);
    connect(process, &QProcess::readyReadStandardOutput, this, &ConsoleWindow::readyReadStandardOutput);
    connect(process, &QProcess::readyReadStandardError, this, &ConsoleWindow::readyReadStandardError);
    connect(process, &QProcess::errorOccurred, this, &ConsoleWindow::errorOccurred);

    QStringList printable;
    printable.append(program);
    printable.append(arguments);

    for (auto &x : printable) {
        x = "'" + x + "'";
    }
    ui->text_console->append(printable.join(" "));

    process->setWorkingDirectory(QFileInfo(program).path());
    process->start(program, arguments);
}

ConsoleWindow::~ConsoleWindow()
{
    process->close();
    delete ui;
}

void ConsoleWindow::processStarted() {
}

void ConsoleWindow::enable_console_input() {
    ui->button_continue->setEnabled(true);
    ui->button_send->setEnabled(true);
    ui->button_tools->setEnabled(true);
    ui->line_console->setEnabled(true);
}

void ConsoleWindow::disable_console_input() {
    ui->button_continue->setEnabled(false);
    ui->button_send->setEnabled(false);
    ui->button_tools->setEnabled(false);
    ui->line_console->setEnabled(false);
}

void ConsoleWindow::readyReadStandardOutput() {
    while (process->canReadLine()) {
        auto line = process->readLine().trimmed();
        if (line == "MONITOR") {
            enable_console_input();
        }
        ui->text_console->append(line);
    }
    if (process->bytesAvailable()) {
        ui->text_console->append(process->readAllStandardOutput().trimmed());
    }
}

void ConsoleWindow::readyReadStandardError() {
    ui->text_errors->append(process->readAllStandardError());
    ui->tab_widget->setCurrentIndex(1);
}

void ConsoleWindow::errorOccurred(QProcess::ProcessError error) {
    QString msg;
    switch (error) {
    case QProcess::FailedToStart:
        msg = "Failed to start";
        break;
    case QProcess::Crashed:
        msg = "Crashed";
        break;
    case QProcess::ReadError:
        msg = "Read error";
        break;
    case QProcess::WriteError:
        msg = "Write error";
        break;
    case QProcess::Timedout:
        msg = "Time out";
        break;
    case QProcess::UnknownError:
        msg = "Unknown error";
    }
    ui->text_errors->append(msg);
    ui->tab_widget->setCurrentIndex(1);
}

void ConsoleWindow::on_button_send_clicked() {
    ui->text_console->append(ui->line_console->text());
    auto command = ui->line_console->text().toLocal8Bit().trimmed();
    process->write(command);
    process->write("\n");
    ui->line_console->clear();
    if (command.startsWith("cont")) {
        disable_console_input();
    }
}

void ConsoleWindow::on_button_tools_clicked() {
    auto *tw = new ToolsWindow(this);
    tw->exec();
    if (tw->command.isEmpty()) return;
    ui->text_console->append(tw->command);
    process->write(tw->command.toLocal8Bit());
    process->write("\n");
}

void ConsoleWindow::on_button_continue_clicked() {
    ui->text_console->append("cont");
    process->write("cont\n");
    disable_console_input();
}

