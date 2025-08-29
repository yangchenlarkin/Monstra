import Foundation
import Monstra

let repository = PostRepository()

let detailID = "101"
let favorites = ["101", "102", "103", "bad id", "104", "102"]
let recommendations = ["103", "104", "105", "101", "bad id", "105"]

let group = DispatchGroup()

func mockPostDetailViewModel() {
    print("[Detail ViewModel] start fetch, ids=[\(detailID)]")
    group.enter()
    repository.getPost(id: detailID) { result in
        switch result {
        case .success(let post):
            if let post = post {
                print("[Detail ViewModel] ✓ \(post.id): \(post.title)")
            } else {
                print("[Detail ViewModel] - not found for id=\(detailID)")
            }
        case .failure(let error):
            print("[Detail ViewModel] ✗ error: \(error)")
        }
        print("[Detail ViewModel] finish fetch, ids=[\(detailID)]")
        group.leave()
    }
}

func mockFavoritesViewModel() {
    print("[Favorites ViewModel] start fetch, ids=\(favorites)")
    group.enter()
    repository.getPostsBatch(ids: favorites) { results in
        var ok = 0, miss = 0
        for id in favorites {
            if case let .success(post) = results[id] ?? .failure(NSError()) {
                if post != nil { ok += 1 } else { miss += 1 }
            }
        }
        print("[Favorites ViewModel] completed: ok=\(ok) miss=\(miss)")
        print("[Favorites ViewModel] finish fetch, ids=\(favorites)")
        group.leave()
    }
}

func mockRecommendationsCarouselModel() {
    print("[Carousel ViewModel] start fetch, ids=\(recommendations)")
    group.enter()
    repository.getPostsBatch(ids: recommendations) { results in
        var ok = 0, miss = 0
        for id in recommendations {
            if case let .success(post) = results[id] ?? .failure(NSError()) {
                if post != nil { ok += 1 } else { miss += 1 }
            }
        }
        print("[Carousel ViewModel] completed: ok=\(ok) miss=\(miss)")
        print("[Carousel ViewModel] finish fetch, ids=\(recommendations)")
        group.leave()
    }
}

print("Starting concurrent ViewModels (detail + favorites + carousel) ...")
mockPostDetailViewModel()
mockFavoritesViewModel()
mockRecommendationsCarouselModel()

group.wait()
print("All viewModels done.")


