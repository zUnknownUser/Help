package promotions

type Promotion struct {
	ID       string
	Eyebrow  string
	Title    string
	ImageURL string
	Features []Feature
	Actions  []Action
}

type Feature struct {
	IconKey string
	Label   string
}

type Action struct {
	ID      string
	Label   string
	IconKey string
	Style   string
}
