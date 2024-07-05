#include "consolewindow.h"
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

void ConsoleWindow::readyReadStandardOutput() {
    while (process->canReadLine()) {
        ui->text_console->append(process->readLine().trimmed());
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

void ConsoleWindow::on_button_send_clicked()
{
    ui->text_console->append(ui->line_console->text());
    process->write(ui->line_console->text().toLocal8Bit());
    process->write("\n");
    ui->line_console->clear();
}
