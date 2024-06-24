#include "consolewindow.h"
#include "ui_consolewindow.h"
#include <QDebug>
#include <QProcess>

ConsoleWindow::ConsoleWindow(QWidget *parent, QString program, QStringList arguments) :
    QDialog(parent),
    ui(new Ui::ConsoleWindow)
{
    ui->setupUi(this);
    this->setWindowFlags(Qt::Window);

    process = new QProcess(this);

    connect(process, SIGNAL(started()), this, SLOT(processStarted()));
    connect(process, SIGNAL(readyReadStandardOutput()), this, SLOT(readyReadStandardOutput()));
    connect(process, SIGNAL(readyReadStandardError()), this, SLOT(readyReadStandardError()));

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
}

void ConsoleWindow::on_button_send_clicked()
{
    ui->text_console->append(ui->line_console->text());
    process->write(ui->line_console->text().toLocal8Bit());
    process->write("\n");
    ui->line_console->clear();
}
