using System;
using System.IO;
using System.Windows.Forms;

namespace ToontownLauncher
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            try
            {
                Application.Run(new MainForm());
            }
            catch (Exception ex)
            {
                File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "launcher-error.txt"), ex.ToString());
                MessageBox.Show(ex.Message, "Toontown Launcher");
            }
        }
    }
}
