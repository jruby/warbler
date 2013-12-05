JBUNDLER_CLASSPATH = []
JBUNDLER_CLASSPATH << './local_repository/org/slf4j/slf4j-simple/1.7.5/slf4j-simple-1.7.5.jar'
JBUNDLER_CLASSPATH << './local_repository/org/slf4j/slf4j-api/1.7.5/slf4j-api-1.7.5.jar'
JBUNDLER_CLASSPATH.freeze
JBUNDLER_CLASSPATH.each { |c| require c }
