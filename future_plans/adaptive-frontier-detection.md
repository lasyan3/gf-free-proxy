# Adaptive Frontier Detection

## Problème actuel

Le proxy utilise un `start_page` fixe (5) pour les requêtes RSS. Cette approche a des limites :

- **Flux irrégulier** : GF uploade ~7 torrents/h en moyenne, mais c'est variable
- **Rate limit** : GF limite à ~10 requêtes avant 429
- **Frontière mobile** : La limite entre contenu < 36h et > 36h se déplace selon le flux

Avec `start_page=5` fixe :
- Flux faible → on scanne des pages vides inutilement
- Flux fort → on pourrait louper du contenu éligible en pages 1-4

## Solution proposée : Adaptive Frontier Detection

Aussi appelé "Middle-out Boundary Search", proche de l'algorithme **Galloping Search** utilisé dans Timsort.

### Principe

```
Page 5 ──┬── 0% éligible ──→ avancer (6, 7, 8...)
         │
         ├── 100% éligible ──→ reculer (4, 3, 2...) pour ne rien louper
         │
         └── mix (frontière!) ──→ scanner vers l'avant
```

### Algorithme

1. **Probe initial** : Commencer à page 5 (estimation heuristique)
2. **Détection de direction** :
   - Si 0% éligible → tout est < 36h → avancer
   - Si 100% éligible → tout est > 36h → reculer pour trouver le début
   - Si mix → frontière trouvée → scanner vers l'avant
3. **Scan** : Une fois la frontière trouvée, scanner vers l'avant jusqu'au quota ou rate limit

### Implémentation

```python
async def fetch_gf_torrents_adaptive(
    query: Optional[str] = None,
    categories: Optional[list[int]] = None,
    imdb_id: Optional[str] = None,
    season: Optional[int] = None,
    episode: Optional[int] = None,
    api_token: Optional[str] = None,
) -> list[dict]:
    """
    Fetch torrents using adaptive frontier detection.
    Optimizes API calls by finding the 36h boundary dynamically.
    """
    PROBE_PAGE = 5
    MAX_REQUESTS = 10
    eligible_torrents = []
    pages_fetched = 0

    page = PROBE_PAGE
    direction = None

    async with httpx.AsyncClient(timeout=30.0) as client:
        while pages_fetched < MAX_REQUESTS and len(eligible_torrents) < RESULTS_LIMIT:
            # Fetch page
            torrents = await fetch_page(client, page, query, categories, imdb_id, api_token)
            pages_fetched += 1

            if not torrents:
                break

            # Analyze eligibility ratio
            eligible = [t for t in torrents if is_torrent_eligible(t)]
            ratio = len(eligible) / len(torrents)

            if ratio == 0:
                # Tout < 36h → avancer pour trouver contenu éligible
                page += 1
                direction = "forward"

            elif ratio == 1.0:
                # Tout > 36h → reculer si on n'a pas encore avancé
                eligible_torrents.extend(eligible)
                if direction == "forward" or page == 1:
                    # Frontière dépassée ou butée page 1, maintenant avancer
                    page += 1
                    direction = "forward"
                else:
                    # Reculer pour ne rien louper
                    page -= 1
                    direction = "backward"

            else:
                # Mix = frontière trouvée, collecter et avancer
                eligible_torrents.extend(eligible)
                page += 1
                direction = "forward"

            # Respectful delay
            await asyncio.sleep(1.0)

    return eligible_torrents[:RESULTS_LIMIT]
```

### Comportement selon le flux

| Flux | Frontière estimée | Parcours typique | Requêtes | Contenu récupéré |
|------|-------------------|------------------|----------|------------------|
| Faible | Page 3 | 5→4→3→2→3→4→5→6→7→8 | 10 | ~8 pages |
| Normal | Page 8 | 5→6→7→8→9→10→11→12→13→14 | 10 | ~7 pages |
| Fort | Page 12 | 5→6→7→8→9→10→11→12→13→14 | 10 | ~3 pages (partiel) |

### Avantages

1. **Ne loupe jamais de contenu** : Si page 5 est 100% éligible, on recule automatiquement
2. **S'adapte au flux** : Pas de start_page fixe qui devient obsolète
3. **Optimise les requêtes** : Utilise intelligemment les 10 requêtes disponibles
4. **Pas de configuration** : Fonctionne automatiquement quel que soit le rythme d'upload GF

### Inconvénients

1. **Complexité** : Plus complexe que le start_page fixe actuel
2. **Cas limite flux fort** : Si la frontière est > page 15, on n'atteint pas assez de contenu
3. **Latence variable** : Temps de réponse dépend de où se trouve la frontière

### Tests à implémenter

```python
def test_adaptive_frontier_low_flux():
    """Frontière page 3 - doit reculer depuis page 5"""
    # Mock: pages 1-2 = mix, pages 3+ = 100% éligible
    # Expected: 5→4→3→4→5→6... (recule puis avance)

def test_adaptive_frontier_normal_flux():
    """Frontière page 8 - doit avancer depuis page 5"""
    # Mock: pages 1-7 = 0%, page 8 = mix, pages 9+ = 100%
    # Expected: 5→6→7→8→9→10...

def test_adaptive_frontier_high_flux():
    """Frontière page 14 - atteint rate limit avant frontière"""
    # Mock: pages 1-13 = 0%, pages 14+ = éligible
    # Expected: 5→6→...→14 (10 requêtes, résultats partiels)
```

## Statut

- [ ] Implémentation
- [ ] Tests unitaires
- [ ] Tests d'intégration
- [ ] Documentation utilisateur
- [ ] Déploiement

## Références

- [Exponential Search (Wikipedia)](https://en.wikipedia.org/wiki/Exponential_search)
- [Galloping Search in Timsort](https://en.wikipedia.org/wiki/Timsort#Galloping_mode)
