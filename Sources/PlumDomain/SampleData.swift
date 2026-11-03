import Foundation

public enum SampleData {
    public static let user = PlumUser(username: "milesatlarge", displayName: "Miles Carter")
    public static let restaurant = Restaurant(name: "BoccaLupo", neighborhood: "Inman Park", address: "753 Edgewood Ave NE, Atlanta", cuisine: "Italian", priceLevel: 3)
    public static let dish = Dish(restaurantID: restaurant.id, name: "Black Spaghetti")
    public static let post = FoodPost(authorID: user.id, restaurantID: restaurant.id, dishRatings: [DishRating(dishID: dish.id, stars: 4.5)], photoURLs: [URL(string: "https://images.unsplash.com/photo-1473093295043-cdd812d0e601")!], caption: "Worth the wait.")
}
