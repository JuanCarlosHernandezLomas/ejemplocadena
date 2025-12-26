package org.example;
import java.io.BufferedReader;
import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class BuscarCadenaEnCarpeta {

    // Ajusta extensiones si quieres filtrar
    private static final String[] EXTENSIONES_TEXTO = {
            ".txt", ".log", ".csv", ".json", ".xml", ".yml", ".yaml",
            ".java", ".properties", ".md", ".sql"
    };

    public static void main(String[] args) {

        Path carpetaRaiz = Paths.get("C:\\Users\\lomas\\Desktop\\demo_busqueda_unica_prueba");
        String cadenaABuscar = "prueba";

        // Charset recomendado. Si tus archivos están en UTF-8, déjalo así.
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
        final String needle = cadena; // si quieres case-insensitive, cambia aquí

        // Recorre todo recursivo
        try (var stream = Files.walk(carpetaRaiz)) {
            stream
                    .filter(Files::isRegularFile)
                    .filter(path -> esArchivoTexto(path))
                    .forEach(path -> {
                        try {
                            Resultado r = buscarEnArchivo(path, needle, charset, incluirDetalleLineas);
                            if (r != null) {
                                encontrados.add(r);
                            }
                        } catch (Exception ex) {
                            // Si hay archivos binarios o con encoding raro, no revienta todo.
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

        // Para no imprimir líneas infinitas, guardamos máximo 20
        List<String> lineas = new ArrayList<>();

        try (BufferedReader br = Files.newBufferedReader(archivo, charset)) {
            String line;
            while ((line = br.readLine()) != null) {
                numeroLinea++;

                // Búsqueda "case-sensitive"
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
