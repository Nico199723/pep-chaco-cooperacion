# Protocolo de relevamiento y revisión semanal

El analista propone; únicamente el administrador humano decide qué publicar. Nunca marcar oportunidades como aprobadas ni aprobar fuentes en nombre del administrador.

## Insumos de cada corrida

Base aprobada actual, exportación de rechazos con motivos, fuentes semilla/aprobadas/bloqueadas y pendientes de la corrida anterior. Las fuentes iniciales incluyen los links y mensajes aportados por el usuario en este proyecto (archivo “Texto pegado.txt”). Los mensajes son pistas: fechas, montos y elegibilidad deben verificarse nuevamente en la fuente primaria. No publicar conversaciones privadas, teléfonos ni nombres de remitentes.

Si falta un insumo, indicar la limitación. No afirmar que se contrastaron rechazos o duplicados contra información a la que no se accedió. Mantener un inventario de IDs entregados para no repetirlos y no deducir una aprobación a partir de una entrega anterior.

## Método

Buscar por eje × sector × ámbito, en español, inglés y portugués. Ampliar más allá de las semillas: bancos multilaterales, fondos climáticos, ONU, UE, cooperación bilateral, fundaciones y organismos nacionales. Los agregadores sirven para descubrir; verificar siempre bases y fuente oficial del financiador. Confirmar elegibilidad de Argentina y del actor destinatario del Chaco. Separar área provincial canalizadora de beneficiario elegible.

Asignar un eje principal y hasta dos secundarios: Chaco + Fuerte (productivo, económico, sostenible); Chaco + Humanizado (equidad y bienestar); Chaco con + Identidad (identidad local y proyección regional); Chaco + Ágil (Estado moderno, transversal). Lo no clasificable va a “Sin eje / a revisar”, con explicación. Usar las áreas y subáreas del Mapa del Estado indicadas por el usuario; verificar su vigencia al asignar. Proponer “a confirmar” cuando exista duda. Relaciones Internacionales y Asuntos Estratégicos articulan oportunidades internacionales.

Nunca inventar fechas, montos, URLs ni elegibilidad. Datos faltantes: “No informado”. Confianza Alto: fuente oficial verificada; Medio: incompleta; Bajo: no verificable. No confundir confianza con aprobación ni atribuir probabilidades de éxito.

Alertas: pago para postular; organismo no identificable; dominio no oficial; sin fechas ni bases; link no primario; montos sin requisitos; inelegibilidad para Argentina/Chaco; único origen de terceros. Explicar y bajar puntaje; ante dudas, confianza Baja. Relevancia: 5 encaje directo y elegible; 4 encaje fuerte con requisitos abordables; 3 interés condicionado; 2 encaje débil o alertas importantes; 1 no verificable/inelegible. Fundamentar en una línea; no presentar el puntaje como certeza estadística.

Ordenar por puntaje descendente y cierre más próximo (destacar próximos 30 días). Máximo 25 propuestas nuevas por corrida; excedentes a “Pendientes de siguiente corrida”. Comparar con la base y con rechazos: no repetir rechazos sin cambio sustancial verificable. Los cambios de aprobadas deben proponerse, nunca sobrescribirse automáticamente. Conservar vencidas para anticipar futuras ediciones.

Proponer nuevos financiadores recurrentes como fuentes **Candidatas**, con nombre, URL oficial, tipo, ejes y por qué sirven. No reintroducir fuentes bloqueadas sin un cambio fundamentado.

## Entrega

(a) Resumen de cinco líneas; (b) propuestas nuevas por puntaje; (c) fuentes candidatas; (d) cambios y vencimientos de lo aprobado; (e) CSV importable con todas las filas en **Pendiente de revisión**. Incluir un CSV separado de excedentes cuando corresponda.

Usar los encabezados de `plantilla-semanal.csv`: los 22 campos de la oportunidad y ocho de revisión. Origen: Semilla/Descubierta. Fecha de relevamiento: fecha real de verificación. Fuente primaria verificada: URL efectivamente revisada, o “No informado”. El link oficial es distinto de la página donde se encontró una pista. En “Posible duplicado de”, indicar el ID visible conocido; el importador vuelve a resolver el vínculo interno y no confía en un UUID enviado por CSV.

Sin publicación automática, sin claves de servicio y sin escritura de datos privados en el repositorio público.
