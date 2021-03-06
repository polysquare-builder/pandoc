module Text.Pandoc.Readers.Docx.StyleMap (  StyleMaps(..)
                                          , defaultStyleMaps
                                          , getStyleMaps
                                          , getStyleId
                                          , hasStyleName
                                          ) where

import           Text.XML.Light
import           Text.Pandoc.Readers.Docx.Util
import           Control.Monad.State
import           Data.Char  (toLower)
import           Data.Maybe (fromMaybe)
import qualified Data.Map                      as M

newtype ParaStyleMap = ParaStyleMap ( M.Map String String )
newtype CharStyleMap = CharStyleMap ( M.Map String String )

class StyleMap a where
  alterMap :: (M.Map String String -> M.Map String String) -> a -> a
  getMap :: a -> M.Map String String

instance StyleMap ParaStyleMap where
  alterMap f (ParaStyleMap m) = ParaStyleMap $ f m
  getMap (ParaStyleMap m) = m

instance StyleMap CharStyleMap where
  alterMap f (CharStyleMap m) = CharStyleMap $ f m
  getMap (CharStyleMap m) = m

insert :: (StyleMap a) => String -> String -> a -> a
insert k v = alterMap $ M.insert k v

getStyleId :: (StyleMap a) => String -> a -> String
getStyleId s = M.findWithDefault (filter (/=' ') s) (map toLower s) . getMap

hasStyleName :: (StyleMap a) => String -> a -> Bool
hasStyleName styleName = M.member (map toLower styleName) . getMap

data StyleMaps = StyleMaps { sNameSpaces   :: NameSpaces
                           , sParaStyleMap :: ParaStyleMap
                           , sCharStyleMap :: CharStyleMap
                           }

data StyleType = ParaStyle | CharStyle

defaultStyleMaps :: StyleMaps
defaultStyleMaps = StyleMaps { sNameSpaces = []
                             , sParaStyleMap = ParaStyleMap M.empty
                             , sCharStyleMap = CharStyleMap M.empty
                             }

type StateM a = StateT StyleMaps Maybe a

getStyleMaps :: Element -> StyleMaps
getStyleMaps docElem = fromMaybe state' $ execStateT genStyleMap state'
    where
    state' = defaultStyleMaps {sNameSpaces = elemToNameSpaces docElem}
    genStyleItem e = do
      styleType <- getStyleType e
      styleId <- getAttrStyleId e
      nameValLowercase <- map toLower `fmap` getNameVal e
      case styleType of
        ParaStyle -> modParaStyleMap $ insert nameValLowercase styleId
        CharStyle -> modCharStyleMap $ insert nameValLowercase styleId
    genStyleMap = do
      style <- elemName' "style"
      let styles = findChildren style docElem
      forM_ styles genStyleItem

modParaStyleMap :: (ParaStyleMap -> ParaStyleMap) -> StateM ()
modParaStyleMap f = modify $ \s ->
  s {sParaStyleMap = f $ sParaStyleMap s}

modCharStyleMap :: (CharStyleMap -> CharStyleMap) -> StateM ()
modCharStyleMap f = modify $ \s ->
  s {sCharStyleMap = f $ sCharStyleMap s}

getStyleType :: Element -> StateM StyleType
getStyleType e = do
  styleTypeStr <- getAttrType e
  case styleTypeStr of
    "paragraph" -> return ParaStyle
    "character" -> return CharStyle
    _           -> lift   Nothing

getAttrType :: Element -> StateM String
getAttrType el = do
  name <- elemName' "type"
  lift $ findAttr name el

getAttrStyleId :: Element -> StateM String
getAttrStyleId el = do
  name <- elemName' "styleId"
  lift $ findAttr name el

getNameVal :: Element -> StateM String
getNameVal el = do
  name <- elemName' "name"
  val <- elemName' "val"
  lift $ findChild name el >>= findAttr val

elemName' :: String -> StateM QName
elemName' name = do
  namespaces <- gets sNameSpaces
  return $ elemName namespaces "w" name
