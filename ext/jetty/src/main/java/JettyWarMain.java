
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.ServerConnector;
import org.eclipse.jetty.webapp.WebAppContext;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

public class JettyWarMain {

    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            throw new IllegalArgumentException("missing war file name");
        }

        // Ensure we have a "work" directory for the webapp
        if (System.getProperty("jetty.home") != null) {
            new File(System.getProperty("jetty.home"), "work").mkdirs();
        }

        WebAppContext webapp = new WebAppContext();
        webapp.setContextPath("/");
        webapp.setExtractWAR(true);
        webapp.setWar(args[0]);
        webapp.setDefaultsDescriptor(webdefaultPath());

        Server server = new Server();
        ServerConnector connector = new ServerConnector(server);
        connector.setPort(Integer.getInteger("jetty.port",8080).intValue());
        server.addConnector(connector);
        server.setHandler(webapp);
        server.start();
        server.join();
    }

    private static String webdefaultPath() throws Exception {
        String path = System.getProperty("jetty.home", System.getProperty("java.io.tmpdir")) + System.getProperty("file.separator") + "webdefault.xml";
        FileOutputStream out = new FileOutputStream(path);
        InputStream is = JettyWarMain.class.getResourceAsStream("/webdefault.xml");
        try {
            byte[] buf = new byte[4096];
            int bytesRead = 0;
            while ((bytesRead = is.read(buf)) != -1) {
                out.write(buf, 0, bytesRead);
            }
        } finally {
            is.close();
            out.close();
        }
        return path;
    }
}
