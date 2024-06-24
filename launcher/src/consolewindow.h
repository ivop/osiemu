#ifndef CONSOLEWINDOW_H
#define CONSOLEWINDOW_H

#include <QDialog>
#include <QProcess>

namespace Ui {
class ConsoleWindow;
}

class ConsoleWindow : public QDialog
{
    Q_OBJECT

public:
    explicit ConsoleWindow(QWidget *parent, QString program, QStringList arguments);
    ~ConsoleWindow();

private slots:
    void on_button_send_clicked();
    void readyReadStandardOutput();
    void readyReadStandardError();
    void processStarted();

private:
    Ui::ConsoleWindow *ui;
    QProcess *process;
};

#endif // CONSOLEWINDOW_H
