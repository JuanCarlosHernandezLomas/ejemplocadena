package org.example;

import java.io.*;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.zip.GZIPInputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

public class BuscarCadenaEnCarpetaZip{

    // Extensiones de texto "directas"
    private static final String[] EXTENSIONES_TEXTO = {
            ".txt", ".log", ".csv", ".json", ".xml", ".yml", ".yaml",
            ".java", ".properties", ".md", ".sql"
    };

    // Extensiones comprimidas que vamos a leer descomprimiendo
    private static final String[] EXTENSIONES_COMPRIMIDAS = { ".gz", ".zip" };

    public static void main(String[] args) {

        Path carpetaRaiz = Paths.get("C:\\Users\\lomas\\Desktop\\demo_busqueda_unica_prueba");
        String cadenaABuscar = "prueba";

        Charset charset = StandardCharsets.UTF_8;

        try {
            List<Resultado> resultados = buscarEnCarpeta(carpetaRaiz, cadenaABuscar, charset, true);

            if (resultados.isEmpty()) {
                System.out.println("No se encontró la cadena: \"" + cadenaABuscar + "\"");
            } else {
                System.out.println("Encontrado en " + resultados.size() + " archivo(s):");
                for (Resultado r : resultados) {
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
            System.err.println("Error leyendo archivos: " + e.getMessage());
        }
    }

    /**
     * @param incluirDetalleLineas si true, guarda lineas donde apareció (limitadas)
     */
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
                    .forEach(path -> {
                        try {
                            String lower = path.getFileName().toString().toLowerCase(Locale.ROOT);

                            // 1) Archivo de texto normal
                            if (esArchivoTexto(path)) {
                                Resultado r = buscarEnArchivoTexto(path, needle, charset, incluirDetalleLineas);
                                if (r != null) encontrados.add(r);
                                return;
                            }

                            // 2) .gz (leer descomprimiendo)
                            if (lower.endsWith(".gz")) {
                                Resultado r = buscarEnGz(path, needle, charset, incluirDetalleLineas);
                                if (r != null) encontrados.add(r);
                                return;
                            }

                            // 3) .zip (leer entradas)
                            if (lower.endsWith(".zip")) {
                                List<Resultado> rz = buscarEnZip(path, needle, charset, incluirDetalleLineas);
                                encontrados.addAll(rz);
                            }

                        } catch (Exception ex) {
                            System.err.println("No se pudo procesar: " + path + " -> " + ex.getMessage());
                        }
                    });
        }

        return encontrados;
    }

    // ===========================
    // Texto normal
    // ===========================
    private static Resultado buscarEnArchivoTexto(Path archivo,
                                                  String needle,
                                                  Charset charset,
                                                  boolean incluirDetalleLineas) throws IOException {
        try (InputStream is = Files.newInputStream(archivo)) {
            return buscarEnInputStream(is, archivo, null, needle, charset, incluirDetalleLineas);
        }
    }

    // ===========================
    // .gz (GZIP)
    // ===========================
    private static Resultado buscarEnGz(Path gzFile,
                                        String needle,
                                        Charset charset,
                                        boolean incluirDetalleLineas) throws IOException {

        try (InputStream fis = Files.newInputStream(gzFile);
             GZIPInputStream gis = new GZIPInputStream(fis)) {

            // nombre “real” sugerido: quitamos .gz
            String originalName = quitarExtension(gzFile.getFileName().toString(), ".gz");

            return buscarEnInputStream(gis, gzFile, originalName, needle, charset, incluirDetalleLineas);
        }
    }

    // ===========================
    // .zip (ZIP)
    // ===========================
    private static List<Resultado> buscarEnZip(Path zipFile,
                                               String needle,
                                               Charset charset,
                                               boolean incluirDetalleLineas) throws IOException {

        List<Resultado> resultados = new ArrayList<>();

        try (InputStream fis = Files.newInputStream(zipFile);
             ZipInputStream zis = new ZipInputStream(fis)) {

            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {

                // ignorar directorios
                if (entry.isDirectory()) continue;

                String entryName = entry.getName();
                String entryLower = entryName.toLowerCase(Locale.ROOT);

                // solo leemos entradas que parezcan texto por extensión
                if (!tieneExtensionTexto(entryLower)) {
                    continue;
                }

                // IMPORTANTE: No cerramos zis aquí (se reutiliza).
                Resultado r = buscarEnInputStream(
                        zis,
                        zipFile,
                        zipFile.getFileName() + "::" + entryName,
                        needle,
                        charset,
                        incluirDetalleLineas
                );

                if (r != null) resultados.add(r);

                zis.closeEntry();
            }
        }

        return resultados;
    }

    // ===========================
    // Core: buscar dentro de un InputStream (texto, gz, zip entry)
    // ===========================
    private static Resultado buscarEnInputStream(InputStream is,
                                                 Path archivoRealEnDisco,
                                                 String nombreMostrableOverride,
                                                 String needle,
                                                 Charset charset,
                                                 boolean incluirDetalleLineas) throws IOException {

        int ocurrencias = 0;
        int numeroLinea = 0;
        List<String> lineas = new ArrayList<>();

        try (BufferedReader br = new BufferedReader(new InputStreamReader(is, charset))) {
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
            Path carpeta = archivoRealEnDisco.getParent();

            String nombreFinal = (nombreMostrableOverride != null && !nombreMostrableOverride.isBlank())
                    ? nombreMostrableOverride
                    : archivoRealEnDisco.getFileName().toString();

            // rutaCompleta: mostramos el archivo real (zip/gz) y si aplica la “entrada”
            String rutaCompleta = archivoRealEnDisco.toAbsolutePath().toString();
            if (nombreMostrableOverride != null && nombreMostrableOverride.contains("::")) {
                rutaCompleta = archivoRealEnDisco.toAbsolutePath() + " :: " + nombreMostrableOverride;
            }

            return new Resultado(
                    rutaCompleta,
                    carpeta != null ? carpeta.toAbsolutePath().toString() : "",
                    nombreFinal,
                    ocurrencias,
                    lineas
            );
        }
        return null;
    }

    // ===========================
    // Helpers
    // ===========================
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
        return tieneExtensionTexto(name);
    }

    private static boolean tieneExtensionTexto(String filenameLower) {
        for (String ext : EXTENSIONES_TEXTO) {
            if (filenameLower.endsWith(ext)) return true;
        }
        return false;
    }

    private static String quitarExtension(String name, String ext) {
        if (name.toLowerCase(Locale.ROOT).endsWith(ext)) {
            return name.substring(0, name.length() - ext.length());
        }
        return name;
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

