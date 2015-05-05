/**
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

import java.io.Closeable;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyHash;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.Block;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;
import org.jruby.util.JRubyFile;

public class WarblerJar {
    public static void create(Ruby runtime) {
        RubyModule task = runtime.getClassFromPath("Warbler::Jar");
        task.defineAnnotatedMethods(WarblerJar.class);
    }

    @JRubyMethod
    public static IRubyObject create_jar(ThreadContext context, IRubyObject self,
        IRubyObject jar_path, IRubyObject entries) {
        final Ruby runtime = context.runtime;

        if (!(entries instanceof RubyHash)) {
            throw runtime.newArgumentError("expected a hash for the second argument");
        }

        RubyHash hash = (RubyHash) entries;
        try {
            FileOutputStream file = newFile(jar_path);
            try {
                ZipOutputStream zip = new ZipOutputStream(file);
                addEntries(context, zip, hash);
                zip.finish();
            } finally {
                close(file);
            }
        } catch (IOException e) {
            if (runtime.isDebug()) {
                e.printStackTrace(runtime.getOut());
            }
            throw runtime.newIOErrorFromException(e);
        }

        return runtime.getNil();
    }

    @JRubyMethod
    public static IRubyObject entry_in_jar(ThreadContext context, IRubyObject self,
        IRubyObject jar_path, IRubyObject entry) {
        final Ruby runtime = context.runtime;
        try {
            InputStream entryStream = getStream(jar_path.convertToString().getUnicodeValue(),
                                                entry.convertToString().getUnicodeValue());
            try {
                byte[] buf = new byte[16384];
                ByteList blist = new ByteList();
                int bytesRead = -1;
                while ((bytesRead = entryStream.read(buf)) != -1) {
                    blist.append(buf, 0, bytesRead);
                }
                IRubyObject stringio = runtime.getModule("StringIO");
                return stringio.callMethod(context, "new", runtime.newString(blist));
            } finally {
                close(entryStream);
            }
        } catch (IOException e) {
            if (runtime.isDebug()) {
                e.printStackTrace(runtime.getOut());
            }
            throw runtime.newIOErrorFromException(e);
        }
    }

    private static void addEntries(ThreadContext context, ZipOutputStream zip, RubyHash entries) throws IOException {
        RubyArray keys = entries.keys().sort(context, Block.NULL_BLOCK);
        for (int i = 0; i < keys.getLength(); i++) {
            IRubyObject key = keys.entry(i);
            IRubyObject value = entries.op_aref(context, key);
            addEntry(context, zip, key.convertToString().getUnicodeValue(), value);
        }
    }

    private static void addEntry(ThreadContext context, ZipOutputStream zip, String entryName, IRubyObject value) throws IOException {
        if (value.respondsTo("read")) {
            RubyString str = (RubyString) value.callMethod(context, "read").checkStringType();
            ByteList strByteList = str.getByteList();
            byte[] contents = strByteList.getUnsafeBytes();
            zip.putNextEntry(new ZipEntry(entryName));
            zip.write(contents, strByteList.getBegin(), strByteList.getRealSize());
        } else {
            File f;
            if (value.isNil() || (f = getFile(value)).isDirectory()) {
                zip.putNextEntry(new ZipEntry(entryName + "/"));
            } else {
                String path = f.getPath();
                if (!f.exists()) {
                    path = value.convertToString().getUnicodeValue();
                }

                try {
                    InputStream inFile = getStream(path, null);
                    try {
                        zip.putNextEntry(new ZipEntry(entryName));
                        byte[] buf = new byte[16384];
                        int bytesRead;
                        while ((bytesRead = inFile.read(buf)) != -1) {
                            zip.write(buf, 0, bytesRead);
                        }
                    } finally {
                        close(inFile);
                    }
                } catch (IOException e) {
                    System.err.println("File not found; " + path + " not in archive");
                }
            }
        }
    }

    private static FileOutputStream newFile(IRubyObject jar_path) throws IOException {
        return new FileOutputStream(getFile(jar_path));
    }

    private static File getFile(IRubyObject path) {
        return JRubyFile.create(path.getRuntime().getCurrentDirectory(),
                                path.convertToString().getUnicodeValue());
    }

    private static void close(Closeable c) {
        try {
            c.close();
        } catch (Exception e) {
        }
    }

    private static Pattern PROTOCOL = Pattern.compile("^[a-z][a-z0-9]+:");

    private static InputStream getStream(String jar, String entry) throws IOException {
        Matcher m = PROTOCOL.matcher(jar);
        while (m.find()) {
            jar = jar.substring(m.end());
            m = PROTOCOL.matcher(jar);
        }

        String[] path = jar.split("!/");
        InputStream stream = new FileInputStream(path[0]);
        for (int i = 1; i < path.length; i++) {
            stream = entryInJar(stream, path[i]);
        }

        if (entry == null) {
            return stream;
        }

        return entryInJar(stream, entry);
    }

    private static String trimTrailingSlashes(String path) {
        if (path.endsWith("/")) {
            return path.substring(0, path.length() - 1);
        } else {
            return path;
        }
    }

    private static InputStream entryInJar(InputStream jar, String entry) throws IOException {
        entry = trimTrailingSlashes(entry);

        ZipInputStream jstream = new ZipInputStream(jar);
        ZipEntry zentry;
        while ((zentry = jstream.getNextEntry()) != null) {
            if (trimTrailingSlashes(zentry.getName()).equals(entry)) {
                return jstream;
            }
            jstream.closeEntry();
        }
        throw new FileNotFoundException("entry '" + entry + "' not found in " + jar);
    }
}
