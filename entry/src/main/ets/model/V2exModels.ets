export interface V2exNode {
  name: string;
  title: string;
  avatar_large?: string;
}

export interface V2exMember {
  username: string;
  tagline?: string;
  avatar_large?: string;
}

export interface V2exTopic {
  id: number;
  title: string;
  content: string;
  url?: string;
  replies: number;
  last_modified: number;
  last_touched: number;
  node?: V2exNode;
  member?: V2exMember;
}

export interface V2exReply {
  id: number;
  content: string;
  created: number;
  member?: V2exMember;
}
