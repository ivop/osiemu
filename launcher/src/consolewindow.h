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
    explicit ConsoleWindow(QWidget *parent, const QString& program, const QStringList& arguments);
    ~ConsoleWindow() override;

private slots:
    void on_button_send_clicked();
    void readyReadStandardOutput();
    void readyReadStandardError();
    void processStarted();
    void errorOccurred(QProcess::ProcessError error);

    void on_button_tools_clicked();

private:
    Ui::ConsoleWindow *ui;
    QProcess *process;
};

#endif // CONSOLEWINDOW_H
