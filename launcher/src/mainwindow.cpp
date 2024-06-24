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
    this->hide();
    QString program = "./osiemu";
    QStringList arguments;

    ConsoleWindow *console = new ConsoleWindow(this, program, arguments);
    console->exec();
    this->show();
    delete(console);
}
