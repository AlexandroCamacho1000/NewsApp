abstract class RemoteArticlesEvent {
  const RemoteArticlesEvent();
}

class GetArticles extends RemoteArticlesEvent {
  const GetArticles();
}

// ✅ COPIA Y PEGA ESTE EVENTO NUEVO:
class RefreshArticles extends RemoteArticlesEvent {
  const RefreshArticles();
}
// ✅ FIN DEL NUEVO EVENTO