
import org.eclipse.jetty.server.Connector;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.nio.SelectChannelConnector;
import org.eclipse.jetty.webapp.WebAppContext;

public class JettyWarMain {
    public static void main(String[] args) throws Exception {
        String war = "test.war";
        if (args.length > 0) {
            war = args[0];
        }

        Server server = new Server();

        Connector connector = new SelectChannelConnector();
        connector.setPort(Integer.getInteger("jetty.port",8080).intValue());
        server.setConnectors(new Connector[]{connector});

        WebAppContext webapp = new WebAppContext();
        webapp.setContextPath("/");
        webapp.setExtractWAR(true);
        webapp.setWar(war);
        webapp.setDefaultsDescriptor("src/main/resources/webdefault.xml");

        server.setHandler(webapp);

        server.start();
        server.join();
    }
}
