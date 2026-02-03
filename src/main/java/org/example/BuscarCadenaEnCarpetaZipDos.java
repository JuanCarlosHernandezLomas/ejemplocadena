package org.example;

import java.io.*;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.zip.GZIPInputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

public class BuscarCadenaEnCarpetaZipDos{

    // Extensiones de texto a leer/buscar
    private static final String[] EXTENSIONES_TEXTO = {
            ".txt", ".log", ".csv", ".json", ".xml", ".yml", ".yaml",
            ".java", ".properties", ".md", ".sql"
    };

    public static void main(String[] args) {
        Path carpetaRaiz = Paths.get("C:\\Users\\lomas\\Desktop\\demo_busqueda_unica_prueba");
        String cadenaABuscar = "prueba";
        Charset charset = StandardCharsets.UTF_8;

        // Carpeta donde vamos a extraer todo
        Path outputExtracted = Paths.get("C:\\Users\\lomas\\Desktop\\output_extracted");

        try {
            // 1) Extraer todo lo comprimido (.zip y .gz) que se encuentre en carpetaRaiz
            extraerComprimidosRecursivo(carpetaRaiz, outputExtracted);

            // 2) Buscar en la carpeta original
            List<Resultado> resultadosOriginal = buscarEnCarpeta(carpetaRaiz, cadenaABuscar, charset, true);

            // 3) Buscar en lo extraído
            List<Resultado> resultadosExtraidos = buscarEnCarpeta(outputExtracted, cadenaABuscar, charset, true);

            // 4) Unir resultados (si quieres, puedes separar)
            List<Resultado> todos = new ArrayList<>();
            todos.addAll(resultadosOriginal);
            todos.addAll(resultadosExtraidos);

            if (todos.isEmpty()) {
                System.out.println("No se encontró la cadena: \"" + cadenaABuscar + "\"");
            } else {
                System.out.println("Encontrado en " + todos.size() + " archivo(s) (original + extraídos):");
                for (Resultado r : todos) {
                    System.out.println("--------------------------------------------------");
                    System.out.println("Archivo: " + r.rutaCompleta);
                    System.out.println("Carpeta: " + r.carpeta);
                    System.out.println("Nombre : " + r.nombreArchivo);
                    System.out.println("Ocurrencias: " + r.ocurrencias);
                    if (!r.lineasCoinciden.isEmpty()) {
                        System.out.println("Líneas:");
                        for (String linea : r.lineasCoinciden) {
                            System.out.println("  " + linea);
                        }
                    }
                }
            }

        } catch (IOException e) {
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace(System.err);
        }
    }

    // ==========================================================
    // 1) EXTRAER COMPRIMIDOS (ZIP + GZ) EN UNA CARPETA OUTPUT
    // ==========================================================
    public static void extraerComprimidosRecursivo(Path carpetaRaiz, Path outputExtracted) throws IOException {
        if (!Files.exists(carpetaRaiz) || !Files.isDirectory(carpetaRaiz)) {
            throw new IllegalArgumentException("No es carpeta válida: " + carpetaRaiz);
        }

        Files.createDirectories(outputExtracted);

        try (var stream = Files.walk(carpetaRaiz)) {
            stream.filter(Files::isRegularFile).forEach(path -> {
                String name = path.getFileName().toString().toLowerCase(Locale.ROOT);
                try {
                    if (name.endsWith(".zip")) {
                        Path outZipDir = outputExtracted
                                .resolve("zip")
                                .resolve(nombreBaseSeguro(path.getFileName().toString())); // carpeta por zip
                        unzipSeguro(path, outZipDir);
                        System.out.println("ZIP extraído: " + path + " -> " + outZipDir);
                    } else if (name.endsWith(".gz")) {
                        Path outGzDir = outputExtracted.resolve("gz");
                        Files.createDirectories(outGzDir);

                        String outFileName = quitarExtension(path.getFileName().toString(), ".gz");
                        Path outFile = outGzDir.resolve(outFileName);

                        gunzip(path, outFile);
                        System.out.println("GZ extraído:  " + path + " -> " + outFile);
                    }
                } catch (Exception ex) {
                    System.err.println("No se pudo extraer: " + path + " -> " + ex.getMessage());
                }
            });
        }
    }

    /**
     * Descomprime ZIP evitando Zip Slip.
     */
    private static void unzipSeguro(Path zipFile, Path outputDir) throws IOException {
        Files.createDirectories(outputDir);

        try (InputStream fis = Files.newInputStream(zipFile);
             ZipInputStream zis = new ZipInputStream(fis)) {

            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                Path outPath = outputDir.resolve(entry.getName()).normalize();

                // Protección Zip Slip: el archivo extraído debe quedar dentro de outputDir
                if (!outPath.startsWith(outputDir)) {
                    throw new IOException("Zip Slip detectado: " + entry.getName());
                }

                if (entry.isDirectory()) {
                    Files.createDirectories(outPath);
                } else {
                    Files.createDirectories(outPath.getParent());
                    try (OutputStream os = Files.newOutputStream(outPath, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING)) {
                        copiar(zis, os);
                    }
                }
                zis.closeEntry();
            }
        }
    }

    /**
     * Descomprime GZ a un archivo destino.
     */
    private static void gunzip(Path gzFile, Path outputFile) throws IOException {
        Files.createDirectories(outputFile.getParent());

        try (InputStream fis = Files.newInputStream(gzFile);
             GZIPInputStream gis = new GZIPInputStream(fis);
             OutputStream os = Files.newOutputStream(outputFile, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING)) {
            copiar(gis, os);
        }
    }

    private static void copiar(InputStream in, OutputStream out) throws IOException {
        byte[] buffer = new byte[8192];
        int len;
        while ((len = in.read(buffer)) != -1) {
            out.write(buffer, 0, len);
        }
    }

    private static String quitarExtension(String name, String ext) {
        if (name.toLowerCase(Locale.ROOT).endsWith(ext)) {
            return name.substring(0, name.length() - ext.length());
        }
        return name;
    }

    /**
     * Para nombres de carpeta seguros (por ejemplo, zip con espacios o caracteres raros).
     */
    private static String nombreBaseSeguro(String fileName) {
        // Ej: "logs backup (1).zip" -> "logs_backup__1_"
        return fileName.replaceAll("[^a-zA-Z0-9._-]", "_");
    }

    // ==========================================================
    // 2) BUSCAR CADENA EN ARCHIVOS DE TEXTO (como tu lógica)
    // ==========================================================
    public static List<Resultado> buscarEnCarpeta(Path carpetaRaiz,
                                                  String cadena,
                                                  Charset charset,
                                                  boolean incluirDetalleLineas) throws IOException {

        if (carpetaRaiz == null || !Files.exists(carpetaRaiz) || !Files.isDirectory(carpetaRaiz)) {
            throw new IllegalArgumentException("La ruta no existe o no es carpeta: " + carpetaRaiz);
        }
        if (cadena == null || cadena.isBlank()) {
            throw new IllegalArgumentException("La cadena a buscar no puede ir vacía.");
        }

        final List<Resultado> encontrados = new ArrayList<>();
        final String needle = cadena;

        try (var stream = Files.walk(carpetaRaiz)) {
            stream
                    .filter(Files::isRegularFile)
                    .filter(BuscarCadenaEnCarpetaZipDos::esArchivoTexto)
                    .forEach(path -> {
                        try {
                            Resultado r = buscarEnArchivo(path, needle, charset, incluirDetalleLineas);
                            if (r != null) encontrados.add(r);
                        } catch (Exception ex) {
                            System.err.println("No se pudo leer: " + path + " -> " + ex.getMessage());
                        }
                    });
        }

        return encontrados;
    }

    private static Resultado buscarEnArchivo(Path archivo,
                                             String needle,
                                             Charset charset,
                                             boolean incluirDetalleLineas) throws IOException {

        int ocurrencias = 0;
        int numeroLinea = 0;
        List<String> lineas = new ArrayList<>();

        try (BufferedReader br = Files.newBufferedReader(archivo, charset)) {
            String line;
            while ((line = br.readLine()) != null) {
                numeroLinea++;

                int count = contarOcurrencias(line, needle);
                if (count > 0) {
                    ocurrencias += count;
                    if (incluirDetalleLineas && lineas.size() < 20) {
                        lineas.add("L" + numeroLinea + ": " + line.trim());
                    }
                }
            }
        }

        if (ocurrencias > 0) {
            Path carpeta = archivo.getParent();
            return new Resultado(
                    archivo.toAbsolutePath().toString(),
                    carpeta != null ? carpeta.toAbsolutePath().toString() : "",
                    archivo.getFileName().toString(),
                    ocurrencias,
                    lineas
            );
        }
        return null;
    }

    private static int contarOcurrencias(String texto, String needle) {
        int count = 0;
        int idx = 0;
        while ((idx = texto.indexOf(needle, idx)) != -1) {
            count++;
            idx += needle.length();
        }
        return count;
    }

    private static boolean esArchivoTexto(Path path) {
        String name = path.getFileName().toString().toLowerCase(Locale.ROOT);
        for (String ext : EXTENSIONES_TEXTO) {
            if (name.endsWith(ext)) return true;
        }
        return false;
    }

    // DTO simple de resultados
    public static class Resultado {
        public final String rutaCompleta;
        public final String carpeta;
        public final String nombreArchivo;
        public final int ocurrencias;
        public final List<String> lineasCoinciden;

        public Resultado(String rutaCompleta, String carpeta, String nombreArchivo, int ocurrencias, List<String> lineasCoinciden) {
            this.rutaCompleta = rutaCompleta;
            this.carpeta = carpeta;
            this.nombreArchivo = nombreArchivo;
            this.ocurrencias = ocurrencias;
            this.lineasCoinciden = lineasCoinciden;
        }
    }
}
