
import org.eclipse.jetty.server.AbstractConnector;
import org.eclipse.jetty.server.Connector;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.nio.SelectChannelConnector;
import org.eclipse.jetty.util.thread.QueuedThreadPool;
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
        AbstractConnector connector = new SelectChannelConnector();
        connector.setPort(Integer.getInteger("jetty.port",8080).intValue());
        connector.setThreadPool(new QueuedThreadPool(Integer.getInteger("jetty.threadpool.size",Runtime.getRuntime().availableProcessors()+1)));
        server.setConnectors(new Connector[]{connector});
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
