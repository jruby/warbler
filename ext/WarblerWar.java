/**
 * Copyright (c) 2010 Engine Yard, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

import java.io.Closeable;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.zip.ZipEntry;
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
import org.jruby.util.JRubyFile;

public class WarblerWar {
    public static void create(Ruby runtime) {
        RubyModule task = runtime.getClassFromPath("Warbler::War");
        task.defineAnnotatedMethods(WarblerWar.class);
    }

    @JRubyMethod
    public static IRubyObject create_war(ThreadContext context, IRubyObject recv, IRubyObject war_path, IRubyObject entries) {
        final Ruby runtime = recv.getRuntime();

        if (!(entries instanceof RubyHash)) {
            throw runtime.newArgumentError("expected a hash for the second argument");
        }

        RubyHash hash = (RubyHash) entries;
        try {
            FileOutputStream file = newFile(war_path);
            try {
                ZipOutputStream zip = new ZipOutputStream(file);
                addEntries(context, zip, hash);
                zip.finish();
            } finally {
                close(file);
            }
        } catch (IOException e) {
            if (runtime.isDebug()) {
                e.printStackTrace();
            }
            throw runtime.newIOErrorFromException(e);
        }

        return runtime.getNil();
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
            byte[] contents = str.getByteList().getUnsafeBytes();
            zip.putNextEntry(new ZipEntry(entryName));
            zip.write(contents);
        } else {
            File f;
            if (value.isNil() || (f = getFile(value)).isDirectory()) {
                zip.putNextEntry(new ZipEntry(entryName + "/"));
            } else {
                FileInputStream inFile = openFile(f);
                try {
                    zip.putNextEntry(new ZipEntry(entryName));
                    byte[] buf = new byte[16384];
                    int bytesRead = -1;
                    while ((bytesRead = inFile.read(buf)) != -1) {
                        zip.write(buf, 0, bytesRead);
                    }
                } finally {
                    close(inFile);
                }
            }
        }
    }

    private static FileOutputStream newFile(IRubyObject war_path) throws IOException {
        return new FileOutputStream(getFile(war_path));
    }

    private static FileInputStream openFile(File file) throws IOException {
        return new FileInputStream(file);
    }

    private static File getFile(IRubyObject path) {
        return JRubyFile.create(path.getRuntime().getCurrentDirectory(),
                                path.convertToString().getUnicodeValue());
    }

    private static void close(Closeable c) {
        try {
            c.close();
        } catch (IOException e) {
        }
    }

}
